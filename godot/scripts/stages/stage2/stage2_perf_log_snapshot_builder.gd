extends RefCounted


func build_snapshot(
	stage: int,
	rock_count: int,
	rock_fragment_count: int,
	water_splash_count: int,
	water_trail_count: int,
	quake_timer: float,
	boss_rage_active: bool,
	water_cannon_phase: String,
	skill_warning_kind: String
) -> Dictionary:
	return {
		"stage": stage,
		"rocks": rock_count,
		"rock_fragments": rock_fragment_count,
		"water_splashes": water_splash_count,
		"water_trail": water_trail_count,
		"quake_timer": quake_timer,
		"boss_rage_active": boss_rage_active,
		"water_cannon_phase": water_cannon_phase,
		"skill_warning_kind": skill_warning_kind,
	}
