extends RefCounted


const ARRAY_FIELDS: Array[String] = [
	"pending_throws",
	"grenades",
	"flares",
	"tear_gas_projectiles",
	"tear_gas_zones",
	"dynamites",
	"placed_dynamites",
	"molotovs",
	"molotov_fire_zones",
	"boomerangs",
	"banana_projectiles",
	"landed_bananas",
	"soap_projectiles",
	"landed_soaps",
	"boomerang_particles",
	"banana_particles",
	"soap_particles",
	"soap_foam_trails",
	"spider_mines",
	"spider_mine_particles",
	"dynamite_explosions",
	"explosion_zones",
	"flare_zones",
]

const FLOAT_FIELDS: Array[String] = [
	"grenade_boss_stun_timer_frames",
	"grenade_boss_knockback_timer_frames",
	"grenade_boss_knockback_vel",
	"flare_boss_confused_timer_frames",
	"tear_gas_boss_pause_timer_frames",
	"tear_gas_boss_pause_text_timer_frames",
	"banana_boss_slip_timer_frames",
	"banana_boss_slip_direction",
	"soap_boss_slip_timer_frames",
	"soap_foam_spawn_timer_frames",
	"spider_mine_slow_timer_frames",
	"spider_mine_slow_text_timer_frames",
	"molotov_fire_slow_timer_frames",
]


func reset(controller: Object, stop_dynamite_fuses_callback: Callable = Callable()) -> void:
	if stop_dynamite_fuses_callback.is_valid():
		stop_dynamite_fuses_callback.call(null)

	for field_name in ARRAY_FIELDS:
		var value: Variant = controller.get(field_name)
		if value is Array:
			value.clear()

	for field_name in FLOAT_FIELDS:
		controller.set(field_name, 0.0)
