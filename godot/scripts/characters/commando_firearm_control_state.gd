extends RefCounted

const CommandoFirearmSlingshotState := preload("res://scripts/characters/commando_firearm_slingshot_state.gd")

const SERVE_WAIT_SUPPRESSED := 1
const SERVE_WAIT_CLEAR_INPUT := 2
const SERVE_WAIT_LATCH_UNTIL_RELEASE := 4

const CONTROL_LOCK_TIMER_FIELDS := [
	"slingshot_control_lock_frames",
	"pistol_control_lock_frames",
	"bazooka_control_lock_frames",
	"net_gun_control_lock_frames",
	"bowling_trap_control_lock_frames",
]


static func needs_effect_update(
	visible_effects: bool,
	pending_boss_damage_units: int,
	pending_special_gauge_gain: float
) -> bool:
	return visible_effects or pending_boss_damage_units > 0 or pending_special_gauge_gain > 0.0


static func needs_runtime_effect_update(target: Object, visible_effects: bool) -> bool:
	if target == null:
		return visible_effects
	return needs_effect_update(
		visible_effects,
		int(target.get("pending_boss_damage_units")),
		float(target.get("pending_special_gauge_gain"))
	)


static func is_player_control_locked(
	lock_timers: Array,
	active_support_call_lock: bool,
	active_suicide_drone: bool
) -> bool:
	for value in lock_timers:
		if float(value) > 0.0:
			return true
	return active_support_call_lock or active_suicide_drone


static func is_runtime_player_control_locked(
	target: Object,
	active_support_call_lock: bool,
	active_suicide_drone: bool
) -> bool:
	var lock_timers: Array = []
	if target != null:
		for field_value in CONTROL_LOCK_TIMER_FIELDS:
			lock_timers.append(float(target.get(str(field_value))))
	return is_player_control_locked(lock_timers, active_support_call_lock, active_suicide_drone)


static func get_movement_speed_multiplier(
	active_suicide_drone: bool,
	ak47_trigger_held: bool,
	_hooked_net_field: bool,
	ak47_multiplier: float,
	_net_gun_multiplier: float
) -> float:
	if active_suicide_drone:
		return 0.0
	return ak47_multiplier if ak47_trigger_held else 1.0


static func get_runtime_movement_speed_multiplier(
	target: Object,
	active_suicide_drone: bool,
	active_hooked_net_field: bool,
	ak47_multiplier: float,
	net_gun_multiplier: float
) -> float:
	return get_movement_speed_multiplier(
		active_suicide_drone,
		bool(target.get("ak47_trigger_held")) if target != null else false,
		active_hooked_net_field,
		ak47_multiplier,
		net_gun_multiplier
	)


static func apply_ak47_trigger_cleared(target: Object) -> void:
	if target == null:
		return
	target.set("ak47_trigger_held", false)
	target.set("ak47_burst_shots_remaining", 0)


static func get_waiting_for_serve(config: Dictionary, deps: Dictionary) -> bool:
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve"):
		return bool(round_state.is_waiting_for_serve())
	if config.has("waiting_for_serve"):
		return bool(config.get("waiting_for_serve", false))
	return false


static func get_serve_wait_fire_suppression(
	input_snapshot: Dictionary,
	config: Dictionary,
	deps: Dictionary,
	suppressed_until_release: bool
) -> Dictionary:
	var flags := _resolve_serve_wait_fire_suppression_flags(
		input_snapshot,
		config,
		deps,
		suppressed_until_release
	)
	return {
		"suppressed": bool(flags & SERVE_WAIT_SUPPRESSED),
		"clear_input_state": bool(flags & SERVE_WAIT_CLEAR_INPUT),
		"suppressed_until_release": bool(flags & SERVE_WAIT_LATCH_UNTIL_RELEASE),
	}


static func apply_runtime_serve_wait_fire_suppression(
	target: Object,
	input_snapshot: Dictionary,
	config: Dictionary,
	deps: Dictionary
) -> bool:
	var suppressed_until_release := false
	if target != null:
		suppressed_until_release = bool(target.get("serve_wait_fire_suppressed_until_release"))
	var flags := _resolve_serve_wait_fire_suppression_flags(
		input_snapshot,
		config,
		deps,
		suppressed_until_release
	)
	if target != null:
		target.set(
			"serve_wait_fire_suppressed_until_release",
			bool(flags & SERVE_WAIT_LATCH_UNTIL_RELEASE)
		)
		if bool(flags & SERVE_WAIT_CLEAR_INPUT):
			apply_serve_wait_firearm_input_cleared(target)
	return bool(flags & SERVE_WAIT_SUPPRESSED)


static func apply_serve_wait_firearm_input_cleared(target: Object) -> void:
	if target == null:
		return
	apply_ak47_trigger_cleared(target)
	target.set("ak47_last_action_pressed", false)
	target.set("bowling_trap_last_action_pressed", false)
	target.set("suicide_drone_last_action_pressed", false)
	if bool(target.get("slingshot_charging")):
		CommandoFirearmSlingshotState.apply_canceled_state(target)
	target.set("slingshot_last_action_pressed", false)
	target.set("slingshot_control_lock_frames", 0.0)
	target.set("pistol_fire_delay_frames", 0.0)
	target.set("pistol_control_lock_frames", 0.0)
	var pending_config: Variant = target.get("pistol_pending_config")
	if pending_config is Dictionary:
		(pending_config as Dictionary).clear()
	else:
		target.set("pistol_pending_config", {})
	target.set("pistol_pending_weapon_id", "")


static func _resolve_serve_wait_fire_suppression_flags(
	input_snapshot: Dictionary,
	config: Dictionary,
	deps: Dictionary,
	suppressed_until_release: bool
) -> int:
	var action_pressed := bool(input_snapshot.get("action_pressed", false))
	if get_waiting_for_serve(config, deps):
		var waiting_flags := SERVE_WAIT_SUPPRESSED | SERVE_WAIT_CLEAR_INPUT
		if action_pressed or suppressed_until_release:
			waiting_flags |= SERVE_WAIT_LATCH_UNTIL_RELEASE
		return waiting_flags
	if suppressed_until_release and action_pressed:
		return SERVE_WAIT_SUPPRESSED | SERVE_WAIT_CLEAR_INPUT | SERVE_WAIT_LATCH_UNTIL_RELEASE
	return 0


static func handle_firearm_reset_input(
	input_snapshot: Dictionary,
	special_gauge: float,
	weapon_controller: Object,
	now_msec: int,
	target: Object,
	base_weapon_id: String
) -> Dictionary:
	var reset_pressed: bool = bool(input_snapshot.get(
		"firearm_reset_just_pressed",
		input_snapshot.get("mouse_middle_just_pressed", false)
	))
	if not reset_pressed:
		return {}
	if weapon_controller == null:
		return {}
	var previous_weapon_id := base_weapon_id
	if weapon_controller.has_method("get_current_weapon_data"):
		previous_weapon_id = str(weapon_controller.get_current_weapon_data().get("weapon_id", base_weapon_id))
	var switched := false
	if weapon_controller.has_method("select_base_weapon"):
		switched = bool(weapon_controller.select_base_weapon(now_msec))
	elif weapon_controller.has_method("set_current_weapon"):
		switched = bool(weapon_controller.set_current_weapon(base_weapon_id))
	if not switched:
		return {}
	apply_ak47_trigger_cleared(target)
	if target != null and bool(target.get("slingshot_charging")):
		CommandoFirearmSlingshotState.apply_canceled_state(target)
	return {
		"handled": true,
		"weapon_id": base_weapon_id,
		"current_weapon_id": base_weapon_id,
		"previous_weapon_id": previous_weapon_id,
		"weapon_switched": previous_weapon_id != base_weapon_id,
		"firearm_reset": true,
		"special_gauge": special_gauge,
	}
