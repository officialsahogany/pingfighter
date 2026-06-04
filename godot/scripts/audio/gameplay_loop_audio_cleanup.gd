extends RefCounted

const STOP_METHODS := [
	"stop_dash_delay",
	"stop_boomerang_loop",
	"stop_spider_mine_walk_loop",
	"stop_plasma_charge",
	"stop_plasma_shock",
	"stop_warp_gate_loop",
	"stop_magnum_grip",
	"stop_smasher_wheel_loop",
	"stop_shield_kiting_wind_up",
	"stop_viper_jetpack_loop",
	"stop_chaos_spear_windup",
	"stop_chaos_spear_flying",
	"stop_chaos_spear_impact",
	"stop_chaos_spear_blackhole_loop",
	"stop_commando_supply_radio_loop",
	"stop_commando_supply_aircraft_loop",
	"stop_commando_fire_support_aircraft_loop",
	"stop_commando_suicide_drone_loop",
	"stop_ragnarok_shock_loop",
	"stop_electric_shock_loop",
	"stop_lingpet_gatling_loop",
	"stop_bomb_surprise_urgent_tick",
	"stop_stage2_quake_loop",
	"stop_stage3_psychoball_loop",
	"stop_stage4_magnetic_loop",
	"stop_stage5_hongryun_fireball",
	"stop_stage5_hongryun_charge",
	"stop_stage5_hongryun_shoot",
]


static func stop_all(audio: Object) -> void:
	if audio == null:
		return
	for method in STOP_METHODS:
		if audio.has_method(method):
			audio.call(method)
