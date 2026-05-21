extends RefCounted


static func record_playfield_overlay_counters(
	battle_perf_logger: Object,
	leaf_particle_count: int,
	starpoint_particle_count: int,
	starpoint_drop_count: int,
	border_flash_active: bool,
	rage_tint_active: bool,
	fragment_flash_active: bool,
	skill_warning_active: bool
) -> void:
	if battle_perf_logger == null or not battle_perf_logger.has_method("record_counter_sample"):
		return
	battle_perf_logger.record_counter_sample("stage2.overlay.leaf_particles", leaf_particle_count)
	battle_perf_logger.record_counter_sample("stage2.overlay.starpoint_particles", starpoint_particle_count)
	battle_perf_logger.record_counter_sample("stage2.overlay.starpoint_drops", starpoint_drop_count)
	battle_perf_logger.record_counter_sample("stage2.overlay.border_flash_active", 1 if border_flash_active else 0)
	battle_perf_logger.record_counter_sample("stage2.overlay.rage_tint_active", 1 if rage_tint_active else 0)
	battle_perf_logger.record_counter_sample("stage2.overlay.fragment_flash_active", 1 if fragment_flash_active else 0)
	battle_perf_logger.record_counter_sample("stage2.overlay.skill_warning_active", 1 if skill_warning_active else 0)


static func record_playfield_obstacle_counters(
	battle_perf_logger: Object,
	rock_count: int,
	rock_fragment_count: int,
	water_splash_count: int,
	quake_active: bool,
	water_cannon_active: bool,
	water_trail_count: int
) -> void:
	if battle_perf_logger == null or not battle_perf_logger.has_method("record_counter_sample"):
		return
	battle_perf_logger.record_counter_sample("stage2.obstacles.rocks", rock_count)
	battle_perf_logger.record_counter_sample("stage2.obstacles.rock_fragments", rock_fragment_count)
	battle_perf_logger.record_counter_sample("stage2.obstacles.water_splashes", water_splash_count)
	battle_perf_logger.record_counter_sample("stage2.obstacles.quake_active", 1 if quake_active else 0)
	battle_perf_logger.record_counter_sample("stage2.obstacles.water_cannon_active", 1 if water_cannon_active else 0)
	battle_perf_logger.record_counter_sample("stage2.obstacles.water_trail", water_trail_count)
