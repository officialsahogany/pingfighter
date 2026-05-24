extends RefCounted

const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const VISIBLE_EFFECT_ARRAY_FIELDS := [
	"projectiles",
	"muzzle_flashes",
	"impact_flashes",
	"lingering_effects",
	"shell_casings",
	"pistol_feedbacks",
	"support_calls",
	"bowling_traps",
]

const VISIBLE_TIMER_FIELDS := [
	"slingshot_control_lock_frames",
	"pistol_fire_delay_frames",
	"pistol_post_fire_animation_frames",
	"weapon_fire_sheet_timer_frames",
	"pistol_control_lock_frames",
	"bazooka_control_lock_frames",
	"bazooka_fire_animation_frames",
	"bazooka_firing_pose_frames",
	"bazooka_muzzle_flash_frames",
	"net_gun_control_lock_frames",
	"net_gun_throw_pose_frames",
	"net_gun_harpoon_flash_frames",
	"bowling_trap_control_lock_frames",
	"bowling_trap_install_pose_frames",
	"suicide_drone_cooldown_frames",
]


static func build_slingshot_state(
	charging: bool,
	charge_timer_frames: float,
	charge_level: int,
	charge_threshold_frames: float,
	charge_tick_interval_frames: float,
	cooldown_frames: float,
	cooldown_max_frames: float,
	gauge_spent: float,
	control_lock_frames: float,
	control_lock_max_frames: float
) -> Dictionary:
	return {
		"charging": charging,
		"charge_timer_frames": charge_timer_frames,
		"charge_level": charge_level,
		"charge_ratio": clamp(charge_timer_frames / charge_threshold_frames, 0.0, 1.0),
		"charge_tick_ratio": fmod(max(0.0, charge_timer_frames), charge_tick_interval_frames) / charge_tick_interval_frames,
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"gauge_spent": gauge_spent,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
	}


static func build_runtime_slingshot_state(
	target: Object,
	charge_threshold_frames: float,
	charge_tick_interval_frames: float,
	cooldown_max_frames: float,
	control_lock_max_frames: float
) -> Dictionary:
	if target == null:
		return build_slingshot_state(
			false,
			0.0,
			0,
			charge_threshold_frames,
			charge_tick_interval_frames,
			0.0,
			cooldown_max_frames,
			0.0,
			0.0,
			control_lock_max_frames
		)
	return build_slingshot_state(
		bool(target.get("slingshot_charging")),
		float(target.get("slingshot_charge_timer_frames")),
		int(target.get("slingshot_charge_level")),
		charge_threshold_frames,
		charge_tick_interval_frames,
		float(target.get("slingshot_cooldown_frames")),
		cooldown_max_frames,
		float(target.get("slingshot_gauge_spent")),
		float(target.get("slingshot_control_lock_frames")),
		control_lock_max_frames
	)


static func build_pistol_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	fire_delay_frames: float,
	fire_delay_max_frames: float,
	post_fire_animation_frames: float,
	post_fire_animation_max_frames: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"fire_delay_frames": fire_delay_frames,
		"fire_delay_max_frames": fire_delay_max_frames,
		"shot_pending": fire_delay_frames > 0.0,
		"post_fire_animation_frames": post_fire_animation_frames,
		"post_fire_animation_max_frames": post_fire_animation_max_frames,
		"animation_active": fire_delay_frames > 0.0 or post_fire_animation_frames > 0.0,
	}


static func build_runtime_pistol_state(
	target: Object,
	fire_delay_max_frames: float,
	post_fire_animation_max_frames: float
) -> Dictionary:
	if target == null:
		return build_pistol_state(0.0, 0.0, 0.0, 0.0, 0.0, fire_delay_max_frames, 0.0, post_fire_animation_max_frames)
	return build_pistol_state(
		float(target.get("pistol_cooldown_frames")),
		float(target.get("pistol_cooldown_max_frames")),
		float(target.get("pistol_control_lock_frames")),
		float(target.get("pistol_control_lock_max_frames")),
		float(target.get("pistol_fire_delay_frames")),
		fire_delay_max_frames,
		float(target.get("pistol_post_fire_animation_frames")),
		post_fire_animation_max_frames
	)


static func build_weapon_fire_sheet_state(
	weapon_id: String,
	timer_frames: float,
	timer_max_frames: float,
	frame_count: int
) -> Dictionary:
	return {
		"active": timer_frames > 0.0 and weapon_id != "",
		"weapon_id": weapon_id,
		"timer_frames": timer_frames,
		"timer_max_frames": timer_max_frames,
		"frame_count": frame_count,
	}


static func build_runtime_weapon_fire_sheet_state(target: Object, frame_count: int) -> Dictionary:
	if target == null:
		return build_weapon_fire_sheet_state("", 0.0, 0.0, frame_count)
	return build_weapon_fire_sheet_state(
		str(target.get("weapon_fire_sheet_id")),
		float(target.get("weapon_fire_sheet_timer_frames")),
		float(target.get("weapon_fire_sheet_max_frames")),
		frame_count
	)


static func build_ak47_state(
	trigger_held: bool,
	fire_interval_frames: float,
	fire_interval_max_frames: float,
	burst_shots_remaining: int,
	recoil_accumulation: float,
	movement_speed_multiplier: float
) -> Dictionary:
	return {
		"trigger_held": trigger_held,
		"fire_interval_frames": fire_interval_frames,
		"fire_interval_max_frames": fire_interval_max_frames,
		"burst_shots_remaining": burst_shots_remaining,
		"recoil_accumulation": recoil_accumulation,
		"movement_speed_multiplier": movement_speed_multiplier,
	}


static func build_runtime_ak47_state(target: Object, movement_speed_multiplier: float) -> Dictionary:
	if target == null:
		return build_ak47_state(false, 0.0, 0.0, 0, 0.0, movement_speed_multiplier)
	return build_ak47_state(
		bool(target.get("ak47_trigger_held")),
		float(target.get("ak47_fire_interval_frames")),
		float(target.get("ak47_fire_interval_max_frames")),
		int(target.get("ak47_burst_shots_remaining")),
		float(target.get("ak47_recoil_accumulation")),
		movement_speed_multiplier
	)


static func build_bazooka_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	fire_animation_frames: float,
	fire_animation_max_frames: float,
	firing_pose_frames: float,
	firing_pose_max_frames: float,
	muzzle_flash_frames: float,
	muzzle_flash_max_frames: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"fire_animation_frames": fire_animation_frames,
		"fire_animation_max_frames": fire_animation_max_frames,
		"firing_pose_frames": firing_pose_frames,
		"firing_pose_max_frames": firing_pose_max_frames,
		"muzzle_flash_frames": muzzle_flash_frames,
		"muzzle_flash_max_frames": muzzle_flash_max_frames,
		"firing_pose": firing_pose_frames > 0.0,
	}


static func build_runtime_bazooka_state(
	target: Object,
	fire_animation_max_frames: float,
	firing_pose_max_frames: float,
	muzzle_flash_max_frames: float
) -> Dictionary:
	if target == null:
		return build_bazooka_state(
			0.0,
			0.0,
			0.0,
			0.0,
			0.0,
			fire_animation_max_frames,
			0.0,
			firing_pose_max_frames,
			0.0,
			muzzle_flash_max_frames
		)
	return build_bazooka_state(
		float(target.get("bazooka_cooldown_frames")),
		float(target.get("bazooka_cooldown_max_frames")),
		float(target.get("bazooka_control_lock_frames")),
		float(target.get("bazooka_control_lock_max_frames")),
		float(target.get("bazooka_fire_animation_frames")),
		fire_animation_max_frames,
		float(target.get("bazooka_firing_pose_frames")),
		firing_pose_max_frames,
		float(target.get("bazooka_muzzle_flash_frames")),
		muzzle_flash_max_frames
	)


static func build_net_gun_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	throw_pose_frames: float,
	throw_pose_max_frames: float,
	harpoon_flash_frames: float,
	harpoon_flash_max_frames: float,
	player_slow_multiplier: float,
	hooked_net_active: bool
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"throw_pose_frames": throw_pose_frames,
		"throw_pose_max_frames": throw_pose_max_frames,
		"harpoon_flash_frames": harpoon_flash_frames,
		"harpoon_flash_max_frames": harpoon_flash_max_frames,
		"throw_pose": throw_pose_frames > 0.0,
		"player_slow_multiplier": player_slow_multiplier,
		"hooked_net_active": hooked_net_active,
	}


static func build_runtime_net_gun_state(
	target: Object,
	cooldown_max_frames: float,
	control_lock_max_frames: float,
	throw_pose_max_frames: float,
	harpoon_flash_max_frames: float,
	player_slow_multiplier: float
) -> Dictionary:
	if target == null:
		return build_net_gun_state(
			0.0,
			cooldown_max_frames,
			0.0,
			control_lock_max_frames,
			0.0,
			throw_pose_max_frames,
			0.0,
			harpoon_flash_max_frames,
			player_slow_multiplier,
			false
		)
	return build_net_gun_state(
		float(target.get("net_gun_cooldown_frames")),
		cooldown_max_frames,
		float(target.get("net_gun_control_lock_frames")),
		control_lock_max_frames,
		float(target.get("net_gun_throw_pose_frames")),
		throw_pose_max_frames,
		float(target.get("net_gun_harpoon_flash_frames")),
		harpoon_flash_max_frames,
		player_slow_multiplier,
		CommandoFirearmLingeringNetFieldState.has_active_hooked_net_field(target.get("lingering_effects"))
	)


static func build_bowling_trap_state(
	cooldown_frames: float,
	cooldown_max_frames: float,
	control_lock_frames: float,
	control_lock_max_frames: float,
	install_pose_frames: float,
	install_pose_max_frames: float,
	installing: bool,
	install_progress: float
) -> Dictionary:
	return {
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"control_lock_frames": control_lock_frames,
		"control_lock_max_frames": control_lock_max_frames,
		"install_pose_frames": install_pose_frames,
		"install_pose_max_frames": install_pose_max_frames,
		"installing": installing,
		"install_progress": install_progress,
	}


static func build_runtime_bowling_trap_state(
	target: Object,
	cooldown_max_frames: float,
	control_lock_max_frames: float,
	install_pose_max_frames: float
) -> Dictionary:
	if target == null:
		return build_bowling_trap_state(
			0.0,
			cooldown_max_frames,
			0.0,
			control_lock_max_frames,
			0.0,
			install_pose_max_frames,
			false,
			0.0
		)
	var traps: Array = CommandoFirearmValueUtils.get_array(target.get("bowling_traps"))
	return build_bowling_trap_state(
		float(target.get("bowling_trap_cooldown_frames")),
		cooldown_max_frames,
		float(target.get("bowling_trap_control_lock_frames")),
		control_lock_max_frames,
		float(target.get("bowling_trap_install_pose_frames")),
		install_pose_max_frames,
		CommandoFirearmBowlingTrapGeometry.has_installing_trap(traps),
		CommandoFirearmBowlingTrapGeometry.get_install_progress(traps)
	)


static func build_suicide_drone_state(
	active: bool,
	cooldown_frames: float,
	cooldown_max_frames: float,
	grace_frames: float,
	pos: Vector2,
	velocity: Vector2
) -> Dictionary:
	return {
		"active": active,
		"cooldown_frames": cooldown_frames,
		"cooldown_max_frames": cooldown_max_frames,
		"grace_frames": grace_frames,
		"pos": pos,
		"velocity": velocity,
	}


static func build_runtime_suicide_drone_state(
	target: Object,
	cooldown_max_frames: float
) -> Dictionary:
	var projectiles: Array = []
	var cooldown_frames := 0.0
	if target != null:
		projectiles = CommandoFirearmValueUtils.get_array(target.get("projectiles"))
		cooldown_frames = float(target.get("suicide_drone_cooldown_frames"))
	for value in projectiles:
		var projectile: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if (
			CommandoFirearmValueUtils.get_projectile_weapon_id(projectile, "") != "suicide_drone"
			or CommandoFirearmValueUtils.get_projectile_kind(projectile) != "drone"
		):
			continue
		return build_suicide_drone_state(
			true,
			cooldown_frames,
			cooldown_max_frames,
			float(projectile.get("grace_timer_frames", 0.0)),
			CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
			CommandoFirearmValueUtils.get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
		)
	return build_suicide_drone_state(
		false,
		cooldown_frames,
		cooldown_max_frames,
		0.0,
		Vector2.ZERO,
		Vector2.ZERO
	)


static func build_actor_context(
	effects_visible: bool,
	projectiles: Array,
	muzzle_flashes: Array,
	impact_flashes: Array,
	lingering_effects: Array,
	shell_casings: Array,
	pistol_feedbacks: Array,
	pistol_state: Dictionary,
	slingshot_state: Dictionary,
	ak47_state: Dictionary,
	bazooka_state: Dictionary,
	net_gun_state: Dictionary,
	bowling_trap_state: Dictionary,
	suicide_drone_state: Dictionary,
	weapon_fire_sheet_state: Dictionary,
	support_calls: Array,
	bowling_traps: Array
) -> Dictionary:
	return {
		"commando_firearm_projectiles": projectiles.duplicate(true) if effects_visible else [],
		"commando_firearm_muzzle_flashes": muzzle_flashes.duplicate(true) if effects_visible else [],
		"commando_firearm_impact_flashes": impact_flashes.duplicate(true) if effects_visible else [],
		"commando_firearm_lingering_effects": lingering_effects.duplicate(true) if effects_visible else [],
		"commando_firearm_shell_casings": shell_casings.duplicate(true) if effects_visible else [],
		"commando_firearm_pistol_feedbacks": pistol_feedbacks.duplicate(true) if effects_visible else [],
		"commando_firearm_pistol_state": pistol_state,
		"commando_firearm_slingshot_state": slingshot_state,
		"commando_firearm_ak47_state": ak47_state,
		"commando_firearm_bazooka_state": bazooka_state,
		"commando_firearm_net_gun_state": net_gun_state,
		"commando_firearm_bowling_trap_state": bowling_trap_state,
		"commando_firearm_suicide_drone_state": suicide_drone_state,
		"commando_firearm_weapon_fire_sheet_state": weapon_fire_sheet_state,
		"commando_firearm_support_calls": support_calls.duplicate(true) if effects_visible else [],
		"commando_firearm_bowling_traps": bowling_traps.duplicate(true) if effects_visible else [],
	}


static func build_runtime_actor_context(
	target: Object,
	pistol_state: Dictionary,
	slingshot_state: Dictionary,
	ak47_state: Dictionary,
	bazooka_state: Dictionary,
	net_gun_state: Dictionary,
	bowling_trap_state: Dictionary,
	suicide_drone_state: Dictionary,
	weapon_fire_sheet_state: Dictionary
) -> Dictionary:
	if target == null:
		return build_actor_context(
			false,
			[],
			[],
			[],
			[],
			[],
			[],
			pistol_state,
			slingshot_state,
			ak47_state,
			bazooka_state,
			net_gun_state,
			bowling_trap_state,
			suicide_drone_state,
			weapon_fire_sheet_state,
			[],
			[]
		)
	return build_actor_context(
		has_runtime_visible_effects(target),
		CommandoFirearmValueUtils.get_array(target.get("projectiles")),
		CommandoFirearmValueUtils.get_array(target.get("muzzle_flashes")),
		CommandoFirearmValueUtils.get_array(target.get("impact_flashes")),
		CommandoFirearmValueUtils.get_array(target.get("lingering_effects")),
		CommandoFirearmValueUtils.get_array(target.get("shell_casings")),
		CommandoFirearmValueUtils.get_array(target.get("pistol_feedbacks")),
		pistol_state,
		slingshot_state,
		ak47_state,
		bazooka_state,
		net_gun_state,
		bowling_trap_state,
		suicide_drone_state,
		weapon_fire_sheet_state,
		CommandoFirearmValueUtils.get_array(target.get("support_calls")),
		CommandoFirearmValueUtils.get_array(target.get("bowling_traps"))
	)


static func has_visible_effects(effect_arrays: Array, timer_values: Array) -> bool:
	for value in effect_arrays:
		if value is Array and not (value as Array).is_empty():
			return true
	for value in timer_values:
		if float(value) > 0.0:
			return true
	return false


static func has_runtime_visible_effects(target: Object) -> bool:
	if target == null:
		return false
	var effect_arrays: Array = []
	for field_value in VISIBLE_EFFECT_ARRAY_FIELDS:
		effect_arrays.append(CommandoFirearmValueUtils.get_array(target.get(str(field_value))))
	var timer_values: Array = []
	for field_value in VISIBLE_TIMER_FIELDS:
		timer_values.append(float(target.get(str(field_value))))
	return has_visible_effects(effect_arrays, timer_values)
