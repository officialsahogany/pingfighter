extends RefCounted


func build_snapshot(rustle_bushes: Array, rustle_vines: Array) -> Dictionary:
	var active_bush_count := 0
	var active_player_bush_count := 0
	var active_boss_bush_count := 0
	var active_vine_count := 0
	for bush_entry in rustle_bushes:
		var bush: Dictionary = bush_entry
		if float(bush.get("amount", 0.0)) <= 0.05:
			continue
		active_bush_count += 1
		if str(bush.get("area", "")) == "player":
			active_player_bush_count += 1
		else:
			active_boss_bush_count += 1
	for vine_entry in rustle_vines:
		var vine: Dictionary = vine_entry
		if float(vine.get("amount", 0.0)) > 0.05:
			active_vine_count += 1
	return {
		"active_bush_count": active_bush_count,
		"active_player_bush_count": active_player_bush_count,
		"active_boss_bush_count": active_boss_bush_count,
		"active_vine_count": active_vine_count,
	}
