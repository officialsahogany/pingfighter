extends RefCounted


static func get_ball_hit_pulse_kind(weapon_id: String, base_weapon_id: String = "pistol") -> String:
	if weapon_id == base_weapon_id:
		return "commando_base_pistol"
	return "commando_%s" % weapon_id


static func get_fire_audio_methods(weapon_id: String) -> Array[String]:
	match weapon_id:
		"pistol":
			return ["play_commando_pistol_fire"]
		"commando_pistol":
			return ["play_commando_pistol_fire"]
		"ak47":
			return ["play_commando_ak47_fire"]
		"bazooka":
			return ["play_commando_bazooka_fire"]
		"net_gun":
			return ["play_commando_net_gun_fire"]
		"bowling_trap":
			return ["play_commando_bowling_trap_install"]
		"suicide_drone":
			return ["play_commando_suicide_drone_launch"]
	return []


static func get_impact_audio_methods(weapon_id: String) -> Array[String]:
	match weapon_id:
		"pistol":
			return ["play_commando_bullet_impact"]
		"commando_pistol", "ak47":
			return ["play_commando_bullet_impact"]
		"bazooka":
			return ["play_commando_bazooka_impact"]
		"net_gun":
			return ["play_commando_net_gun_capture"]
		"fire_support":
			return ["play_commando_fire_support_bomb"]
		"bowling_trap":
			return ["play_commando_bowling_trap_snap"]
		"suicide_drone":
			return ["play_commando_suicide_drone_explosion"]
	return []
