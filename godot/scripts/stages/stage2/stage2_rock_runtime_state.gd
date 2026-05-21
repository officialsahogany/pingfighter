extends RefCounted


static func update_visual_timers(rock: Dictionary, delta: float) -> void:
	rock["flash"] = max(0.0, float(rock.get("flash", 0.0)) - delta)
	rock["water_target_flash"] = max(0.0, float(rock.get("water_target_flash", 0.0)) - delta)
	rock["phase"] = float(rock.get("phase", 0.0)) + delta * 4.0


static func mark_water_target(rocks: Array, rock_id: int, flash_value: float = 1.0) -> bool:
	for index in range(rocks.size()):
		var rock: Dictionary = rocks[index]
		if int(rock.get("id", -1)) != rock_id:
			continue
		rock["water_target_flash"] = flash_value
		rocks[index] = rock
		return true
	return false


static func clear_water_target_flash(rock: Dictionary) -> void:
	rock["water_target_flash"] = 0.0
