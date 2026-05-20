extends RefCounted


func build_context(movement_locked: bool, water_cannon_phase: String) -> Dictionary:
	return {
		"stage2_boss_movement_locked": movement_locked,
		"stage2_water_cannon_phase": water_cannon_phase,
	}
