extends RefCounted

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")


static func trim_array_from_front(source: Array, max_size: int) -> void:
	if max_size <= 0:
		source.clear()
		return
	var overflow := source.size() - max_size
	if overflow <= 0:
		return
	var write_index := 0
	for read_index in range(overflow, source.size()):
		source[write_index] = source[read_index]
		write_index += 1
	source.resize(write_index)


static func recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


static func get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


static func is_lod_active(quality_scale: float, lod_threshold: float) -> bool:
	return quality_scale < lod_threshold


static func is_severe_lod_active(quality_scale: float, severe_lod_threshold: float) -> bool:
	return quality_scale < severe_lod_threshold


static func get_lod_count(
	base_count: int,
	lod_count: int,
	severe_lod_count: int,
	quality_scale: float,
	lod_threshold: float,
	severe_lod_threshold: float
) -> int:
	if is_severe_lod_active(quality_scale, severe_lod_threshold):
		return max(0, min(base_count, severe_lod_count))
	if not is_lod_active(quality_scale, lod_threshold):
		return base_count
	return max(0, min(base_count, lod_count))


static func build_status(
	ambient_falling_leaf_render_limit: int,
	ambient_falling_leaf_render_limit_severe_lod: int,
	leaf_particle_render_limit: int,
	leaf_particle_render_limit_severe_lod: int,
	rock_fragment_render_limit: int,
	rock_fragment_render_limit_severe_lod: int,
	water_splash_render_limit: int,
	water_splash_render_limit_severe_lod: int,
	starpoint_particle_render_limit: int,
	starpoint_particle_render_limit_severe_lod: int
) -> Dictionary:
	return {
		"ambient_falling_leaf_render_limit": ambient_falling_leaf_render_limit,
		"ambient_falling_leaf_render_limit_severe_lod": ambient_falling_leaf_render_limit_severe_lod,
		"leaf_particle_render_limit": leaf_particle_render_limit,
		"leaf_particle_render_limit_severe_lod": leaf_particle_render_limit_severe_lod,
		"rock_fragment_render_limit": rock_fragment_render_limit,
		"rock_fragment_render_limit_severe_lod": rock_fragment_render_limit_severe_lod,
		"water_splash_render_limit": water_splash_render_limit,
		"water_splash_render_limit_severe_lod": water_splash_render_limit_severe_lod,
		"starpoint_particle_render_limit": starpoint_particle_render_limit,
		"starpoint_particle_render_limit_severe_lod": starpoint_particle_render_limit_severe_lod,
	}
