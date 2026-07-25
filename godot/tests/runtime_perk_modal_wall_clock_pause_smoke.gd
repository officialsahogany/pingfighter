extends SceneTree

const ActiveItemFieldSpawnPortals := preload("res://scripts/items/active_item_field_spawn_portals.gd")
const ActiveItemFieldSpawnScheduler := preload("res://scripts/items/active_item_field_spawn_scheduler.gd")
const ActiveItemPendingThrowRecovery := preload("res://scripts/items/active_item_pending_throw_recovery.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const BlacksmithThorShieldState := preload("res://scripts/characters/blacksmith_thor_shield_state.gd")
const BattleSceneSkillTooltipDriver := preload("res://scripts/core/battle_scene_skill_tooltip_driver.gd")
const CommandoEmergencySupplyState := preload("res://scripts/characters/commando_emergency_supply_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const RoundFlowState := preload("res://scripts/core/round_flow_state.gd")
const SmasherMagnumGripState := preload("res://scripts/characters/smasher_magnum_grip_state.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")
const SmasherWarpGateState := preload("res://scripts/characters/smasher_warp_gate_state.gd")
const SmasherWheelState := preload("res://scripts/characters/smasher_wheel_state.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

const PAUSE_MSEC := 2000
const RESUME_MSEC := 7000
const PAUSED_DURATION_MSEC := RESUME_MSEC - PAUSE_MSEC


class ShiftTarget:
	extends RefCounted

	var calls: Array[Vector2i] = []

	func shift_runtime_perk_modal_time(pause_started_msec: int, resumed_msec: int) -> void:
		calls.append(Vector2i(pause_started_msec, resumed_msec))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_smasher_time_anchors()
	_verify_viper_effective_time_and_buffers()
	_verify_commando_blacksmith_and_round_anchors()
	_verify_active_item_time_anchors_and_fanout()
	_verify_driver_source_contract()
	print("runtime_perk_modal_wall_clock_pause_smoke: ok")
	quit(0)


func _verify_smasher_time_anchors() -> void:
	var wheel := SmasherWheelState.new()
	wheel.active = true
	wheel.start_msec = 1000
	wheel.end_msec = 4000
	wheel.command_buffer = [{"msec": 1800}]
	_pause_and_resume_twice(wheel)
	_expect(wheel.start_msec == 6000, "wheel start anchor must preserve modal duration")
	_expect(wheel.end_msec == 9000, "wheel end anchor must preserve modal duration")
	_expect(int(wheel.command_buffer[0].get("msec", 0)) == 6800, "wheel command buffer must preserve modal duration")

	var warp := SmasherWarpGateState.new()
	warp.active = true
	warp.start_msec = 1000
	warp.end_msec = 4000
	warp.hold_start_msec = 1500
	warp.portals = [{"spawn_msec": 1700}]
	_pause_and_resume_twice(warp)
	_expect(warp.start_msec == 6000 and warp.end_msec == 9000, "warp active window must preserve modal duration")
	_expect(warp.hold_start_msec == 6500, "warp hold anchor must preserve modal duration")
	_expect(int(warp.portals[0].get("spawn_msec", 0)) == 6700, "warp portal spawn anchor must preserve modal duration")

	var magnum := SmasherMagnumGripState.new()
	magnum.active = true
	magnum.start_msec = 1000
	magnum.last_burst_msec = 1600
	magnum.both_held_start_msec = 1800
	_pause_and_resume_twice(magnum)
	_expect(magnum.start_msec == 6000, "magnum active start must preserve modal duration")
	_expect(magnum.last_burst_msec == 6600, "magnum burst anchor must preserve modal duration")
	_expect(magnum.both_held_start_msec == 6800, "magnum hold anchor must preserve modal duration")

	var shield := SmasherShieldKitingState.new()
	shield.last_action_edge_msec = 1800
	shield.post_activate_cooldown_until_msec = 2200
	shield.projectile = {
		"active": true,
		"state": "wind_up",
		"started_msec": 1000,
		"last_update_msec": 1900,
		"outbound_started_msec": 1600,
	}
	_pause_and_resume_twice(shield)
	_expect(shield.last_action_edge_msec == 6800, "shield double-tap anchor must preserve modal duration")
	_expect(shield.post_activate_cooldown_until_msec == 7200, "shield debounce deadline must preserve modal duration")
	_expect(int(shield.projectile.get("started_msec", 0)) == 6000, "shield windup start must preserve modal duration")
	_expect(int(shield.projectile.get("last_update_msec", 0)) == 6900, "shield last update must not create a resume delta spike")
	_expect(int(shield.projectile.get("outbound_started_msec", 0)) == 6600, "shield outbound timeout must preserve modal duration")
	shield.pause_runtime_perk_modal_time(RESUME_MSEC)
	shield.reset_round()
	shield.resume_runtime_perk_modal_time(RESUME_MSEC + 5000)
	_expect(shield.projectile.is_empty(), "round reset must clear shield state without a stale modal resume")

	var power := SmasherPowerSmashState.new()
	power.ghost_state.pending_teleport = {"arrive_msec": 2300}
	_pause_and_resume_twice(power)
	_expect(int(power.ghost_state.pending_teleport.get("arrive_msec", 0)) == 7300, "ghost teleport deadline must preserve modal duration through power-smash owner")


func _verify_viper_effective_time_and_buffers() -> void:
	var viper := ViperSkillRuntime.new()
	viper.shadow_step_activation_msec = 1000
	viper.dive_hold_start_msec = 1200
	viper.ignition_hold_start_msec = 1400
	viper.core_flip_ready_msec = 1500
	viper.core_flip_buffered_until_msec = 2100
	viper.core_flip_last_dash_start_msec = 1300
	viper.core_flip_consumed = false
	viper.dual_glitch_cmd_buffer = [{"time": 1700}]
	viper.chaos_cmd_buffer = [{"time": 1800}]
	viper.pause_runtime_perk_modal_time(PAUSE_MSEC)
	_expect(bool(viper.call("_is_core_flip_ready_window_active", 100000)), "paused Core Flip readiness must use the frozen modal time")
	_expect(viper.core_flip_ready_msec == 1500, "paused snapshot/read queries must not mutate Core Flip readiness")
	viper.pause_runtime_perk_modal_time(PAUSE_MSEC + 1000)
	viper.resume_runtime_perk_modal_time(RESUME_MSEC)
	viper.resume_runtime_perk_modal_time(RESUME_MSEC + 1000)
	_expect(viper.shadow_step_activation_msec == 6000, "Viper Shadow Step window must preserve modal duration")
	_expect(viper.dive_hold_start_msec == 6200 and viper.ignition_hold_start_msec == 6400, "Viper hold anchors must preserve modal duration")
	_expect(viper.core_flip_ready_msec == 6500 and viper.core_flip_buffered_until_msec == 7100, "Viper Core Flip windows must preserve modal duration")
	_expect(viper.core_flip_last_dash_start_msec == 6300, "Viper Core Flip dash anchor must preserve modal duration")
	_expect(int(viper.dual_glitch_cmd_buffer[0].get("time", 0)) == 6700, "Dual Glitch command age must preserve modal duration")
	_expect(int(viper.chaos_cmd_buffer[0].get("time", 0)) == 6800, "Chaos command age must preserve modal duration")


func _verify_commando_blacksmith_and_round_anchors() -> void:
	var supply := CommandoEmergencySupplyState.new()
	supply.tap_deadline_msec = 2250
	supply.suppress_until_msec = 2300
	_pause_and_resume_twice(supply)
	_expect(supply.tap_deadline_msec == 7250 and supply.suppress_until_msec == 7300, "Emergency Supply input windows must preserve modal duration")

	var weapon := CommandoWeaponController.new()
	weapon.last_switch_msec = 1900
	_pause_and_resume_twice(weapon)
	_expect(weapon.last_switch_msec == 6900, "Commando weapon-switch debounce must preserve modal duration")

	var firearm := CommandoFirearmRuntime.new()
	firearm.last_fire_msec = 1800
	firearm.net_constrict_last_tick_msec = 1750
	_pause_and_resume_twice(firearm)
	_expect(firearm.last_fire_msec == 6800, "Commando fire debounce must preserve modal duration")
	_expect(firearm.net_constrict_last_tick_msec == 6750, "Commando net input window must preserve modal duration")

	var thor := BlacksmithThorShieldState.new()
	thor.set("_last_hit_msec", 1700)
	_pause_and_resume_twice(thor)
	_expect(int(thor.get("_last_hit_msec")) == 6700, "Thor Shield hit debounce must preserve modal duration")

	var round_state := RoundFlowState.new()
	round_state.round_start_time_msec = 1000
	_pause_and_resume_twice(round_state)
	_expect(round_state.round_start_time_msec == 6000, "shared round-start lock anchor must preserve modal duration")
	var registry := FakeRegistry.new()
	var routed_round_state := RoundFlowState.new()
	routed_round_state.round_start_time_msec = 1000
	registry.instances["round_flow_state"] = routed_round_state
	var driver := BattleSceneSkillTooltipDriver.new()
	driver.call("_pause_runtime_perk_modal_time", registry, PAUSE_MSEC)
	driver.call("_resume_runtime_perk_modal_time", registry, RESUME_MSEC)
	_expect(routed_round_state.round_start_time_msec == 6000, "registry fanout must use the real round_flow_state key")


func _verify_active_item_time_anchors_and_fanout() -> void:
	var portals := ActiveItemFieldSpawnPortals.new()
	portals.dimension_gate_active = true
	portals.dimension_gate_start_msec = 1000
	portals.dimension_gate_end_msec = 4000
	portals.dimension_gate_next_spawn_msec = 2400
	portals.pending_spawn_items = [{"release_msec": 2300}]
	portals.item_spawn_portals = [{
		"start_msec": 1100,
		"phase_start_msec": 1200,
		"end_msec": 3500,
		"effect_end_msec": 3600,
	}]
	portals.shift_runtime_perk_modal_time(PAUSE_MSEC, RESUME_MSEC)
	_expect(portals.dimension_gate_start_msec == 6000, "dimension-gate start must preserve modal duration")
	_expect(portals.dimension_gate_end_msec == 9000 and portals.dimension_gate_next_spawn_msec == 7400, "dimension-gate deadlines must preserve modal duration")
	_expect(int(portals.pending_spawn_items[0].get("release_msec", 0)) == 7300, "pending field-item release must preserve modal duration")
	_expect(int(portals.item_spawn_portals[0].get("end_msec", 0)) == 8500, "field portal lifetime must preserve modal duration")

	var scheduler := ActiveItemFieldSpawnScheduler.new()
	scheduler.last_item_spawn_msec = 1000
	scheduler.shift_runtime_perk_modal_time(PAUSE_MSEC, RESUME_MSEC)
	_expect(scheduler.last_item_spawn_msec == 6000, "regular item spawn scheduler must preserve modal duration")

	var throw_controller := ActiveItemThrowController.new()
	throw_controller.pending_throws = [{"start_msec": 1000, "release_msec": 2500}]
	throw_controller.shift_runtime_perk_modal_time(PAUSE_MSEC, RESUME_MSEC)
	_expect(int(throw_controller.pending_throws[0].get("start_msec", 0)) == 6000, "throw windup start must preserve modal duration")
	_expect(int(throw_controller.pending_throws[0].get("release_msec", 0)) == 7500, "throw release deadline must preserve modal duration")

	var recovery := ActiveItemPendingThrowRecovery.new()
	recovery.pending_throw_item_backup = {"last_item_use_msec": 1600}
	recovery.shift_runtime_perk_modal_time(PAUSE_MSEC, RESUME_MSEC)
	_expect(int(recovery.pending_throw_item_backup.get("last_item_use_msec", 0)) == 6600, "hidden throw-recovery cooldown backup must preserve modal duration")

	var field_target := ShiftTarget.new()
	var throw_target := ShiftTarget.new()
	var recovery_target := ShiftTarget.new()
	var runtime := ActiveItemRuntime.new()
	runtime.set("_helpers_initialized", true)
	runtime.field_spawn_controller = field_target
	runtime.throw_controller = throw_target
	runtime.pending_throw_recovery = recovery_target
	runtime.pause_runtime_perk_modal_time(PAUSE_MSEC)
	runtime.pause_runtime_perk_modal_time(PAUSE_MSEC + 1000)
	runtime.resume_runtime_perk_modal_time(RESUME_MSEC)
	runtime.resume_runtime_perk_modal_time(RESUME_MSEC + 1000)
	_expect(field_target.calls == [Vector2i(PAUSE_MSEC, RESUME_MSEC)], "active-item field fanout must run once")
	_expect(throw_target.calls == [Vector2i(PAUSE_MSEC, RESUME_MSEC)], "active-item throw fanout must run once")
	_expect(recovery_target.calls == [Vector2i(PAUSE_MSEC, RESUME_MSEC)], "active-item recovery fanout must run once")


func _verify_driver_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_skill_tooltip_driver.gd")
	for state_key: String in [
		"smasher_wheel_state",
		"smasher_warp_gate_state",
		"smasher_magnum_grip_state",
		"smasher_shield_kiting_state",
		"smasher_power_smash_state",
		"viper_skill_runtime",
		"commando_emergency_supply_state",
		"commando_weapon_controller",
		"commando_firearm_runtime",
		"blacksmith_thor_shield_state",
		"round_flow_state",
	]:
		_expect(source.find('"%s"' % state_key) >= 0, "modal time fanout must include %s" % state_key)
	_expect(source.find("active_item_runtime.pause_runtime_perk_modal_time(current_msec)") >= 0, "modal pause driver must fan out to active items")
	_expect(source.find("active_item_runtime.resume_runtime_perk_modal_time(current_msec)") >= 0, "modal resume driver must fan out to active items")


func _pause_and_resume_twice(state: Object) -> void:
	state.pause_runtime_perk_modal_time(PAUSE_MSEC)
	state.pause_runtime_perk_modal_time(PAUSE_MSEC + 1000)
	state.resume_runtime_perk_modal_time(RESUME_MSEC)
	state.resume_runtime_perk_modal_time(RESUME_MSEC + 1000)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
