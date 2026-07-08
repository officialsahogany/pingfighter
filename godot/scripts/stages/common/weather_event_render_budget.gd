extends RefCounted

const LOD_ACTIVE_THRESHOLD := 0.99
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const WEATHER_RENDER_PARTICLE_LIMIT := 72
const WEATHER_RENDER_PARTICLE_LIMIT_LOD := 36
const WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD := 24
const WIND_RENDER_PARTICLE_LIMIT := 32
# Wind is a sparse, cheap effect. Live-index stride decimation makes the visible
# ribbon set change every frame, so keep wind near-full and never stride it.
const WIND_RENDER_PARTICLE_LIMIT_LOD := 32
const WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD := 28
const PARTICLE_RENDER_STRIDE_LOD := 2
const PARTICLE_RENDER_STRIDE_SEVERE_LOD := 3
const SAND_RENDER_STRIDE_LOD := 3
const SAND_RENDER_STRIDE_SEVERE_LOD := 5


static func is_wind_weather_type(weather_type: String) -> bool:
	return weather_type == "breeze" or weather_type == "gust"


# Sparse weather effects run only a handful of live particles, so index-stride
# decimation over the shifting mixed particle array flips which particles survive
# every frame -> the effect stutters / blinks instead of moving smoothly. These
# types must render every particle regardless of LOD. Hail peaks at HAIL_MAX_PARTICLES
# (3) core stones and, with stride 3 (the shipped 72fps severe-LOD default), only one
# of three was drawn AND its array index shifted as impact/burst/shard particles were
# appended and removed, so each hailstone appeared mid-field and vanished instead of
# falling top->bottom. See CLAUDE.md "Godot Stride LOD Sparse Particle Flicker Trap".
static func is_stride_exempt_weather_type(weather_type: String) -> bool:
	return is_wind_weather_type(weather_type) or weather_type == "hail"


static func get_weather_particle_limit(weather_type: String, effect_lod_scale: float = 1.0) -> int:
	if is_wind_weather_type(weather_type):
		return get_lod_count(
			WIND_RENDER_PARTICLE_LIMIT,
			WIND_RENDER_PARTICLE_LIMIT_LOD,
			WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD,
			effect_lod_scale
		)
	return get_lod_count(
		WEATHER_RENDER_PARTICLE_LIMIT,
		WEATHER_RENDER_PARTICLE_LIMIT_LOD,
		WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD,
		effect_lod_scale
	)


static func get_particle_render_stride(effect_lod_scale: float) -> int:
	if is_severe_lod_active(effect_lod_scale):
		return PARTICLE_RENDER_STRIDE_SEVERE_LOD
	if is_lod_active(effect_lod_scale):
		return PARTICLE_RENDER_STRIDE_LOD
	return 1


static func get_particle_render_stride_for_type(weather_type: String, effect_lod_scale: float) -> int:
	if is_stride_exempt_weather_type(weather_type):
		return 1
	return get_particle_render_stride(effect_lod_scale)


static func get_particle_render_stride_for_context(context: Dictionary, effect_lod_scale: float) -> int:
	return get_particle_render_stride_for_type(str(context.get("type", "")), effect_lod_scale)


static func get_sand_render_stride(effect_lod_scale: float) -> int:
	if is_severe_lod_active(effect_lod_scale):
		return SAND_RENDER_STRIDE_SEVERE_LOD
	if is_lod_active(effect_lod_scale):
		return SAND_RENDER_STRIDE_LOD
	return 1


static func get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	if base_count <= 0:
		return 0
	if is_severe_lod_active(effect_lod_scale):
		return clampi(severe_lod_count, 0, base_count)
	if is_lod_active(effect_lod_scale):
		return clampi(lod_count, 0, base_count)
	return base_count


static func is_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale < LOD_ACTIVE_THRESHOLD


static func is_severe_lod_active(effect_lod_scale: float) -> bool:
	return effect_lod_scale <= SEVERE_LOD_ACTIVE_THRESHOLD
