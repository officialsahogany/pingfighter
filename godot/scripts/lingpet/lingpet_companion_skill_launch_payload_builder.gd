extends RefCounted

const FLOAT_PAYLOAD_DEFAULTS := {
	"refire_chance_pct": 50.0,
	"beam_homing_chance_pct": -1.0,
	"banana_count": -1.0,
	"clone_count": -1.0,
	"duration_seconds": -1.0,
	"gravity_strength": -1.0,
	# Serabi 난쟁이마술 (Dwarf Magic) catalog tuning — must be whitelisted here or
	# the catalog *_by_level values never reach the live launch payload and the
	# skill silently uses only its internal fallback tables.
	"shrink_scale": -1.0,
	"shrink_duration": -1.0,
	"boss_slow_multiplier": -1.0,
	"proj_speed": -1.0,
	"proj_homing": -1.0,
	"slip_seconds": -1.0,
	"slip_speed": -1.0,
	"roar_radius": -1.0,
	"ball_boost": -1.0,
	"slow_duration": -1.0,
	"slow_multiplier": -1.0,
	"stun_duration_seconds": 0.0,
	"explosion_radius": 0.0,
	"knockback_power": -1.0,
	"projectile_count": -1.0,
	"fire_duration_seconds": -1.0,
	"mega_chance": -1.0,
	"mega_projectile_count": -1.0,
	"mega_duration_seconds": -1.0,
	"arrow_draw_time": -1.0,
	"arrow_cooldown_min": -1.0,
	"arrow_cooldown_max": -1.0,
	"golden_chance_pct": -1.0,
	"bonus_summon_chance_pct": -1.0,
	"barrier_width": -1.0,
	"bonus_barrier_chance_pct": -1.0,
	"knockback_scale": -1.0,
	"headbutt_count": -1.0,
	"mega_knockback_bonus_pct": -1.0,
	"mega_stun_seconds": -1.0,
	"dash_radius": -1.0,
	"slam_radius": -1.0,
	"hit_stun_seconds": -1.0,
	"self_stun_seconds": -1.0,
	"disable_moving_miss": 0.0,
	"ground_slam": 0.0,
}


func build(
	active_skill: Dictionary,
	skill_id: String,
	active_skill_level_fallback: int,
	companion_pos: Vector2,
	companion_radius: float,
	registry: Object
) -> Dictionary:
	var payload := {
		"companion_pos": companion_pos,
		"companion_radius": companion_radius,
		"registry": registry,
		"active_skill_id": str(active_skill.get("id", skill_id)),
		"active_skill_level": int(active_skill.get("level", active_skill_level_fallback)),
	}
	for raw_key in FLOAT_PAYLOAD_DEFAULTS.keys():
		var key := str(raw_key)
		payload[key] = float(active_skill.get(key, FLOAT_PAYLOAD_DEFAULTS[key]))
	return payload
