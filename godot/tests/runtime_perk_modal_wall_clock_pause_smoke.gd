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
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const SmasherMagnumGripState := preload("res://scripts/characters/smasher_magnum_grip_state.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")
const SmasherWarpGateState := preload("res://scripts/characters/smasher_warp_gate_state.gd")
const SmasherWheelState := preload("res://scripts/characters/smasher_wheel_state.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")

const PAUSE_MSEC := 2000
const RESUME_MSEC := 7000
const PAUSED_DURATION_MSEC := RESUME_MSEC - PAUSE_MSEC
# 실경로 레그에서 "퍽 고르느라 5초 걸렸다"를 재현하기 위해, 모달이 열린 뒤
# 정지 마커를 이만큼 과거로 되감는다(스모크는 실제로 5초를 기다릴 수 없다).
# ⚠️엔진 부팅 직후면 `Time.get_ticks_msec()` 가 이보다 작을 수 있으므로 되감기는
# 0 으로 클램프되고, 기대 시프트는 이 상수가 아니라 **실제 마커에서 유도**한다.
const LIVE_MODAL_SPAN_MSEC := 5000

var _failed := false


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


class ModalTimeRecorder:
	extends RefCounted

	var paused := 0
	var resumed := 0

	func pause_runtime_perk_modal_time(_current_msec: int) -> void:
		paused += 1

	func resume_runtime_perk_modal_time(_current_msec: int) -> void:
		resumed += 1


class LivePathOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var ball_vel := Vector2.ZERO
	var player_collision_cooldown := 0.0


class LivePathCatalog:
	extends RefCounted

	var choices: Array = []

	func get_choices(
		_character_type: String,
		_levels: Dictionary,
		_exclude_instant: bool,
		_target_count: int,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return choices.duplicate(true)


# 운영 레지스트리(GameplayModuleRegistry)를 흉내 낸다: 스킬 상태는 **비-생성
# peek(`get_cached_instance`)** 로만 노출하고, `get_instance` 호출 키를 기록해
# 드라이버가 콜드 생성 경로로 새지 않는지 검사한다.
class LivePathRegistry:
	extends RefCounted

	var runtime_perk_catalog := LivePathCatalog.new()
	var skill_tooltip_driver := BattleSceneSkillTooltipDriver.new()
	var skill_state := SmasherSkillState.new()
	var wheel := SmasherWheelState.new()
	var get_instance_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		get_instance_keys.append(key)
		match key:
			"runtime_perk_catalog":
				return runtime_perk_catalog
			"battle_scene_skill_tooltip_driver":
				return skill_tooltip_driver
			"smasher_skill_state":
				return skill_state
		return null

	func get_cached_instance(key: String) -> Object:
		if key == "smasher_wheel_state":
			return wheel
		return null


func _init() -> void:
	_verify_smasher_time_anchors()
	_verify_viper_effective_time_and_buffers()
	_verify_commando_blacksmith_and_round_anchors()
	_verify_active_item_time_anchors_and_fanout()
	_verify_driver_source_contract()
	_verify_public_cooldown_pause_entry_points_fan_out()
	_verify_live_starpoint_choice_preserves_wheel_window()
	if _failed:
		quit(1)
		return
	print("runtime_perk_modal_wall_clock_pause_smoke: ok")
	quit(0)


# 퍽 모달이 실제로 부르는 진입점은 `pause_skill_cooldowns` / `resume_skill_cooldowns`
# 다(runtime_perk_skill_cooldown_pause -> battle_scene_skill_tooltip_driver).
# 내부 `_pause_runtime_perk_modal_time` 만 직접 호출하는 레그는 그 한 줄이 빠져도
# GREEN 이라 최상위 배선을 못 지킨다 — 여기서 공개 진입점을 관통시킨다.
func _verify_public_cooldown_pause_entry_points_fan_out() -> void:
	var registry := FakeRegistry.new()
	var state_recorders: Dictionary = {}
	for state_key: String in BattleSceneSkillTooltipDriver.RUNTIME_PERK_MODAL_TIME_STATE_KEYS:
		var recorder := ModalTimeRecorder.new()
		state_recorders[state_key] = recorder
		registry.instances[state_key] = recorder
	var active_item_recorder := ModalTimeRecorder.new()
	registry.instances["active_item_runtime"] = active_item_recorder

	var driver := BattleSceneSkillTooltipDriver.new()
	driver.pause_skill_cooldowns(null, registry)
	driver.resume_skill_cooldowns(null, registry)

	for state_key: String in state_recorders.keys():
		var recorder: ModalTimeRecorder = state_recorders[state_key]
		_expect(
			recorder.paused == 1 and recorder.resumed == 1,
			"public cooldown pause/resume must fan modal time out to %s" % state_key
		)
	_expect(
		active_item_recorder.paused == 1 and active_item_recorder.resumed == 1,
		"public cooldown pause/resume must fan modal time out to active items"
	)


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


# 보고된 증상 그대로를 실경로로 재현한다: 풍운천선무 발동 중 스타포인트를 먹고
# (`collect_star_points` -> `open_next_choice` -> `_pause_skill_cooldowns_for_choice`)
# 퍽을 고르면(`choose_selected` -> resume) 발동창이 살아남아야 한다.
# 드라이버를 직접 부르는 레그는 오픈/클로즈 배선 한 줄이 빠져도 GREEN 이라
# 이 레그가 그 위층을 지킨다.
func _verify_live_starpoint_choice_preserves_wheel_window() -> void:
	var state := RuntimePerkState.new()
	var owner := LivePathOwner.new()
	var registry := LivePathRegistry.new()
	var wheel: Object = registry.wheel

	var activated_msec: int = Time.get_ticks_msec()
	wheel.active = true
	wheel.start_msec = activated_msec
	wheel.end_msec = activated_msec + SmasherWheelState.DURATION_MSEC
	var end_msec_before: int = wheel.end_msec

	registry.runtime_perk_catalog.choices = [_build_live_choice("stability_training")]
	var opened: bool = state.collect_star_points(1, "smasher", registry.runtime_perk_catalog, owner, registry)
	_expect(opened and state.is_choice_active(), "starpoint pickup should open the perk choice modal")

	var pause_marker: int = int(wheel.get("_runtime_perk_modal_pause_started_msec"))
	_expect(
		pause_marker >= 0,
		"opening the perk choice must freeze the wheel activation window, marker=%d" % pause_marker
	)
	_expect(
		not registry.get_instance_keys.has("smasher_wheel_state"),
		"modal-time fanout must peek cached instances, never cold-instantiate skill modules"
	)

	# 퍽을 고르는 데 오래 걸린 상황으로 마커를 되감는다. 스모크는 실제로 몇 초를
	# 기다릴 수 없다.
	# ⚠️`Time.get_ticks_msec()` 은 **엔진 부팅 이후 경과**라, 부팅 직후 이 레그에
	# 닿으면 고정 5000 을 빼는 순간 마커가 음수가 된다 → `resume` 이 조기 반환해
	# 시프트가 0 이 되고, 배선은 멀쩡한데 RED 가 나는 **공허 RED** 다. 그래서
	# 되감기를 0 으로 클램프하고, 기대값도 상수가 아니라 실제 마커에서 유도한다.
	var rewound_marker: int = maxi(0, pause_marker - LIVE_MODAL_SPAN_MSEC)
	wheel.set("_runtime_perk_modal_pause_started_msec", rewound_marker)

	state.animation_time = 0.30
	var resume_window_start_msec: int = Time.get_ticks_msec()
	state.choose_selected(owner, registry, Vector2(1280.0, 720.0))
	var resume_window_end_msec: int = Time.get_ticks_msec()
	_expect(not state.is_choice_active(), "selecting the perk should close the modal")
	_expect(
		int(wheel.get("_runtime_perk_modal_pause_started_msec")) == -1,
		"closing the perk choice must release the wheel modal-time marker"
	)

	# 불변식은 "모달이 열려 있던 시간 전부를 되돌려받는다" 이므로, 기대 시프트는
	# `resume 시각 - 되감은 마커` 다. resume 이 정확히 언제 찍혔는지는 모르니
	# `choose_selected` 를 감싼 구간으로 상/하한을 잡는다 — 벽시계 값 자체와
	# 무관하게 성립하는 단언이다.
	var shifted_msec: int = wheel.end_msec - end_msec_before
	var expected_min_msec: int = resume_window_start_msec - rewound_marker
	var expected_max_msec: int = resume_window_end_msec - rewound_marker
	_expect(
		shifted_msec >= expected_min_msec and shifted_msec <= expected_max_msec,
		"wheel activation window must gain the whole modal duration, gained=%dms expected=%d..%dms" % [
			shifted_msec, expected_min_msec, expected_max_msec
		]
	)
	_expect(
		shifted_msec > 0,
		"live-path leg must reproduce a non-zero modal span, gained=%dms" % shifted_msec
	)
	_expect(
		wheel.end_msec > Time.get_ticks_msec(),
		"wheel must still be inside its activation window right after the modal closes"
	)


func _build_live_choice(choice_id: String) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"character_restriction": "smasher",
		"icon_color": Color(0.45, 0.75, 1.0),
		"tree": "training",
		"max_level": 5,
		"current_level": 0,
		"next_level": 1,
	}


func _pause_and_resume_twice(state: Object) -> void:
	state.pause_runtime_perk_modal_time(PAUSE_MSEC)
	state.pause_runtime_perk_modal_time(PAUSE_MSEC + 1000)
	state.resume_runtime_perk_modal_time(RESUME_MSEC)
	state.resume_runtime_perk_modal_time(RESUME_MSEC + 1000)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	# ⚠️`quit()` 은 실행을 즉시 멈추지 않는다 — 게이트가 없으면 말미의 무조건
	# `ok` + `quit(0)` 이 실패 종료코드를 덮어써 공허 GREEN 이 된다.
	_failed = true
	quit(1)
