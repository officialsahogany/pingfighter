extends RefCounted

const FLICKER_TICKS_PER_MSEC := 0.047
const VR_STRATA_BLOCK_SPACING := 180.0
const VR_STRATA_WRAP_PADDING := 180.0


static func get_far_sky_x(camera_x: float, far_sky_width: float, game_width: float, parallax: float = 0.04) -> float:
	return -clampf(camera_x * parallax, 0.0, maxf(0.0, far_sky_width - game_width))


static func get_parallax_tile_offset(camera_x: float, parallax: float, tile_width: float) -> float:
	if tile_width <= 0.0:
		return 0.0
	return fposmod(-camera_x * parallax, tile_width) - tile_width


static func get_world_tile_start(camera_x: float, tile_width: float) -> int:
	var safe_tile_width := maxi(1, int(tile_width))
	return int(floor(camera_x / float(safe_tile_width))) * safe_tile_width


static func get_vr_strata_block_rect(index: int, camera_x: float, game_width: float, underground_top: float) -> Rect2:
	var world_x := float(index) * VR_STRATA_BLOCK_SPACING + 40.0
	var local_x := fposmod(world_x - camera_x * 1.18, game_width + VR_STRATA_WRAP_PADDING) - 90.0
	var height := 8.0 + float((index * 17) % 19)
	var y := underground_top + 18.0 + float((index * 13) % 42)
	return Rect2(Vector2(local_x, y), Vector2(54.0, height))


static func get_flicker_tick(ticks_msec: int) -> int:
	return int(floor(float(ticks_msec) * FLICKER_TICKS_PER_MSEC))


static func discrete_flicker(seed_text: String, ticks_msec: int) -> float:
	var tick := get_flicker_tick(ticks_msec)
	var mixed_hash := int(hash(seed_text)) ^ (tick * 1103515245)
	return float(abs(mixed_hash) % 1000) / 1000.0


static func flicker_alpha(seed_text: String, base_alpha: float, amplitude: float, ticks_msec: int) -> float:
	return clampf(base_alpha + discrete_flicker(seed_text, ticks_msec) * amplitude, 0.0, 1.0)


static func smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
