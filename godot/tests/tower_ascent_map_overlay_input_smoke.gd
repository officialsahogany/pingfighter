extends SceneTree

const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)
const BattleSceneOverlayInputController := preload(
	"res://scripts/core/battle_scene_overlay_input_controller.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var ball_vel := Vector2(170.0, -280.0)
	var perk_resume_score_blocking := false
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRuntimePerkState:
	extends RefCounted

	var capture_calls := 0
	var pause_calls := 0
	var resume_calls := 0
	var arm_calls := 0
	var captured_velocity := Vector2.ZERO

	func _capture_resume_pre_choice_velocity(owner: Object) -> void:
		capture_calls += 1
		captured_velocity = owner.ball_vel

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(owner: Object, _registry: Object) -> void:
		arm_calls += 1
		owner.ball_vel = Vector2.ZERO
		owner.perk_resume_score_blocking = true


class FakeAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_dash_delay() -> void:
		stop_calls += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var instance_reads: Array[String] = []

	func get_instance(key: String) -> Variant:
		instance_reads.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class FakeModalGate:
	extends RefCounted

	var pause_active := false

	func is_pause_menu_active(_module_getter: Callable) -> bool:
		return pause_active


class FakePauseMenu:
	extends RefCounted

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		return false


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Variant:
		return modules.get(key, null)


func _init() -> void:
	_verify_combat_open_close_owns_modal_lifecycle()
	_verify_existing_modal_priority_blocks_open()
	_verify_flag_off_is_inert_and_does_not_instantiate()
	_verify_active_route_flow_borrows_modal_lifecycle()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_map_overlay_input_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_combat_open_close_owns_modal_lifecycle() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	var runtime := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": runtime,
		"game_audio": audio,
	}
	var holder := _combat_holder()
	_send_key(KEY_M, owner, registry, holder)
	_expect(flow.is_map_overlay_active(), "M must open the map overlay during live combat")
	_expect(flow.is_active() and flow.blocks_battle_physics(), "an open map must enter the tower physics-block gate")
	_expect(runtime.capture_calls == 1 and runtime.pause_calls == 1, "combat map open must inherit the GRT-058 capture and pause fanout")
	_expect(audio.stop_calls == 1, "combat map open must stop centralized gameplay loop audio")
	var first_snapshot := flow.export_snapshot()
	_send_key(KEY_M, owner, registry, holder)
	_expect(not flow.is_map_overlay_active(), "a second M press must close the map overlay")
	_expect(runtime.resume_calls == 1 and runtime.arm_calls == 1, "combat map close must resume cooldowns and arm resume safety once")
	_expect(owner.ball_vel == Vector2.ZERO and owner.perk_resume_score_blocking, "map close must freeze the ball and block immediate scoring")
	_expect(flow.export_snapshot() == first_snapshot, "opening and closing the read-only map must not mutate run state")
	_send_key(KEY_M, owner, registry, holder)
	_send_key(KEY_ESCAPE, owner, registry, holder)
	_expect(not flow.is_map_overlay_active(), "ESC must close an open map")
	_expect(runtime.resume_calls == 2 and runtime.arm_calls == 2, "ESC close must use the same resume-safety fanout")


func _verify_existing_modal_priority_blocks_open() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": FakeRuntimePerkState.new(),
		"game_audio": FakeAudio.new(),
	}
	var holder := _combat_holder()
	var modal_gate := FakeModalGate.new()
	modal_gate.pause_active = true
	holder.modules["battle_scene_modal_gate_controller"] = modal_gate
	holder.modules["pause_menu_overlay"] = FakePauseMenu.new()
	_send_key(KEY_M, owner, registry, holder)
	_expect(not flow.is_map_overlay_active(), "an existing pause modal must outrank the map shortcut")


func _verify_flag_off_is_inert_and_does_not_instantiate() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	_send_key(KEY_M, owner, registry, _combat_holder())
	_expect(not flow.is_active(), "flag OFF M input must remain inert")
	_expect(not registry.instance_reads.has("tower_ascent_flow_owner"), "flag OFF M input must not instantiate the tower owner")
	_expect(owner.redraw_requests == 0, "flag OFF M input must not redraw the battle")


func _verify_active_route_flow_borrows_modal_lifecycle() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	var runtime := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": runtime,
		"game_audio": FakeAudio.new(),
	}
	_expect(flow.begin_vertical_slice(owner, Callable(), {"registry": registry, "run_id": "map-borrow"}), "route fixture must begin")
	_expect(runtime.pause_calls == 1, "route flow must own one modal pause")
	flow.handle_input(_key_event(KEY_M))
	_expect(flow.get_phase_name() == "MAP_OVERLAY", "M must open the map over route serving")
	flow.handle_input(_key_event(KEY_ESCAPE))
	_expect(flow.get_phase_name() == "ROUTE_AIM", "closing the map must restore the exact route phase")
	_expect(runtime.resume_calls == 0 and runtime.arm_calls == 0, "borrowed route lifecycle must not resume combat when the map closes")
	flow.call("_finish_vertical_slice")
	_expect(runtime.resume_calls == 1 and runtime.arm_calls == 1, "route owner must retain the one final resume-safety close")


func _combat_holder() -> ModuleHolder:
	var holder := ModuleHolder.new()
	holder.modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_scene_overlay_input_controller": BattleSceneOverlayInputController.new(),
	}
	return holder


func _send_key(
	keycode: Key,
	owner: Object,
	registry: Object,
	holder: ModuleHolder
) -> void:
	BattleSceneInputController.new().handle_unhandled_input(
		_key_event(keycode),
		owner,
		registry,
		Callable(holder, "get_module"),
		{"battle_initialized": true, "stage_landing_intro_started": true}
	)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
