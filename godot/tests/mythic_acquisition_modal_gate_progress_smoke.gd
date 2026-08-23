extends SceneTree

# expect-zero-object-leaks
# Production-path seal for the acquisition cinematic's physics-modal maintenance
# tick. The cinematic must advance through BattleSceneFrameController and the
# real modal gate/item driver; calling cinematic.update() directly would leave
# the starvation bug untested.

const BattleRewardModalInputRouter := preload("res://scripts/core/battle_reward_modal_input_router.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneItemUpdateDriver := preload("res://scripts/core/battle_scene_item_update_driver.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

const EPSILON := 0.0001

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var gameplay_frame_counter := 100
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_legendary_open() -> void:
		calls.append("play_legendary_open")

	func play_legendary_after() -> void:
		calls.append("play_legendary_after")

	func play_legendary_ending() -> void:
		calls.append("play_legendary_ending")

	func stop_legendary_after() -> void:
		calls.append("stop_legendary_after")

	func play_item_get() -> void:
		calls.append("play_item_get")


class FakeActiveItemRuntime:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0

	func pause_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		pause_calls += 1

	func resume_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
		resume_calls += 1


class FakeRuntimePerkState:
	extends RefCounted

	var choice_active := false
	var angel_active := false
	var natural_completion_calls := 0
	var completed_perk_id := ""

	func is_choice_active() -> bool:
		return choice_active

	func is_angel_blessing_modal_active() -> bool:
		return angel_active

	func on_angel_blessing_acquisition_cinematic_finished(
		perk_id: String,
		_owner: Object,
		_registry: Object
	) -> void:
		natural_completion_calls += 1
		completed_perk_id = perk_id
		angel_active = true


class FakeNormalUpdateDriver:
	extends RefCounted

	var update_calls := 0
	var item_driver: Object = null

	func update(owner: Object, registry: Object, delta: float) -> void:
		update_calls += 1
		item_driver.update_mythic_items(owner, registry, delta)


class FakeBoundaryModalGate:
	extends RefCounted

	var block := true

	func should_block_battle_physics_with_perf(
		_module_getter: Callable,
		_perf_logger: Object = null
	) -> bool:
		return block

	func should_block_battle_physics(_module_getter: Callable) -> bool:
		return block

	func is_mythic_acquisition_cinematic_active(module_getter: Callable) -> bool:
		var runtime: Object = module_getter.call("mythic_item_runtime")
		return runtime != null and bool(runtime.is_acquisition_cinematic_active())

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return false

	func is_angel_blessing_modal_active(_module_getter: Callable) -> bool:
		return false


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var mythic_runtime: Object = MythicItemRuntime.new()
	var item_driver: Object = BattleSceneItemUpdateDriver.new()
	var normal_update_driver := FakeNormalUpdateDriver.new()
	var modal_gate: Object = BattleSceneModalGateController.new()

	func _init() -> void:
		normal_update_driver.item_driver = item_driver

	func get_instance(key: String) -> Object:
		match key:
			"game_audio":
				return audio
			"active_item_runtime":
				return active_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"mythic_item_runtime":
				return mythic_runtime
			"battle_scene_item_update_driver":
				return item_driver
			"battle_scene_update_driver":
				return normal_update_driver
			"battle_scene_modal_gate_controller":
				return modal_gate
		return null

	func clear_all() -> void:
		mythic_runtime = null
		item_driver = null
		normal_update_driver.item_driver = null
		modal_gate = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_common_gate_progresses_to_reveal_and_reclaims_input()
	_verify_higher_priority_modal_holds_the_cinematic()
	_verify_natural_completion_releases_angel_followup()
	_verify_blocked_to_open_boundary_ticks_once_per_frame()
	await process_frame

	if _failures.is_empty():
		print("mythic_acquisition_modal_gate_progress_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_common_gate_progresses_to_reveal_and_reclaims_input() -> void:
	var fixture := _make_fixture(false)
	var controller: Object = fixture.controller
	var owner: FakeOwner = fixture.owner
	var registry: FakeRegistry = fixture.registry
	var runtime: Object = registry.mythic_runtime
	var router := BattleRewardModalInputRouter.new()
	var click := _make_click()

	_expect(
		runtime.start_acquisition_cinematic(
			_build_cinematic_item(false),
			Vector2(220.0, 330.0),
			owner,
			registry
		),
		"fixture should start the real mythic acquisition cinematic"
	)
	_expect(
		router.handle_input(click, owner, registry, Callable(registry, "get_instance")),
		"BUILDUP click should be consumed by the real reward-modal router"
	)
	_expect(
		str(runtime.get_acquisition_cinematic_snapshot().get("phase", "")) == "build",
		"BUILDUP click must be discarded instead of starting or queuing absorb"
	)

	_process_frame(controller, owner, registry, 1.21)
	_expect_phase(runtime, "ignite", "blocked production frame should advance BUILDUP to IGNITE")
	_expect_elapsed(runtime, 1.21, "blocked BUILDUP frame must advance exactly delta x1")
	_process_frame(controller, owner, registry, 0.41)
	_expect_phase(runtime, "white_fade", "blocked production frame should advance IGNITE to WHITE_FADE")
	_expect_elapsed(runtime, 1.62, "blocked IGNITE frame must advance exactly delta x1")
	_process_frame(controller, owner, registry, 0.51)
	_expect_phase(runtime, "reveal", "blocked production frame should advance WHITE_FADE to REVEAL")
	_process_frame(controller, owner, registry, 0.49)
	_expect(
		router.handle_input(click, owner, registry, Callable(registry, "get_instance")),
		"pre-arm REVEAL click should still be consumed by the modal router"
	)
	_expect_phase(runtime, "reveal", "pre-arm REVEAL click must be discarded, not deferred")
	_expect(
		not bool(runtime.get_acquisition_cinematic_snapshot().get("absorb_started", true)),
		"discarded early clicks must not arm absorption later"
	)
	_process_frame(controller, owner, registry, 0.02)
	_expect(
		bool(runtime.get_acquisition_cinematic_snapshot().get("waiting_for_click", false)),
		"blocked production frames should reach the armed REVEAL wait"
	)
	_expect(
		router.handle_input(click, owner, registry, Callable(registry, "get_instance")),
		"armed REVEAL click should route through the real reward-modal input owner"
	)
	_expect_phase(runtime, "absorb", "armed click should advance REVEAL to ABSORB")
	_process_frame(controller, owner, registry, 1.51)
	_expect_phase(runtime, "impact", "blocked production frame should advance ABSORB to IMPACT")
	_process_frame(controller, owner, registry, 0.51)
	_expect(not runtime.is_acquisition_cinematic_active(), "blocked production path should naturally complete the cinematic")
	_expect(registry.normal_update_driver.update_calls == 0, "normal gameplay update must stay frozen for every cinematic frame")
	_expect(owner.redraw_requests >= 7, "every blocked cinematic maintenance tick should request a battle redraw")
	_expect(
		not router.handle_input(click, owner, registry, Callable(registry, "get_instance")),
		"reward-modal router must release input immediately after ordinary cinematic completion"
	)
	_cleanup_fixture(fixture)


func _verify_higher_priority_modal_holds_the_cinematic() -> void:
	var fixture := _make_fixture(false)
	var controller: Object = fixture.controller
	var owner: FakeOwner = fixture.owner
	var registry: FakeRegistry = fixture.registry
	var runtime: Object = registry.mythic_runtime
	runtime.start_acquisition_cinematic(_build_cinematic_item(false), Vector2(220.0, 330.0), owner, registry)
	registry.runtime_perk_state.choice_active = true

	_process_frame(controller, owner, registry, 0.25)
	_expect_elapsed(runtime, 0.0, "higher-priority perk choice must hold, not co-tick, the acquisition cinematic")
	registry.runtime_perk_state.choice_active = false
	_process_frame(controller, owner, registry, 0.25)
	_expect_elapsed(runtime, 0.25, "cinematic maintenance should resume when the higher-priority modal closes")
	_cleanup_fixture(fixture)


func _verify_natural_completion_releases_angel_followup() -> void:
	var fixture := _make_fixture(false)
	var controller: Object = fixture.controller
	var owner: FakeOwner = fixture.owner
	var registry: FakeRegistry = fixture.registry
	var runtime: Object = registry.mythic_runtime
	runtime.start_acquisition_cinematic(_build_cinematic_item(true), Vector2(220.0, 330.0), owner, registry)

	_process_frame(controller, owner, registry, 1.21)
	_process_frame(controller, owner, registry, 0.41)
	_process_frame(controller, owner, registry, 0.51)
	_process_frame(controller, owner, registry, 0.51)
	BattleRewardModalInputRouter.new().handle_input(
		_make_click(),
		owner,
		registry,
		Callable(registry, "get_instance")
	)
	_process_frame(controller, owner, registry, 1.51)
	_process_frame(controller, owner, registry, 0.51)

	_expect(registry.runtime_perk_state.natural_completion_calls == 1, "natural production-path completion should notify Angel exactly once")
	_expect(registry.runtime_perk_state.completed_perk_id == "angel_blessing", "natural completion should release the reserved Angel perk id")
	_expect(registry.runtime_perk_state.angel_active, "natural completion callback should synchronously open the Angel follow-up modal")
	_process_frame(controller, owner, registry, 0.25)
	_expect(registry.runtime_perk_state.natural_completion_calls == 1, "Angel-blocked successor frame must not replay cinematic completion")
	_cleanup_fixture(fixture)


func _verify_blocked_to_open_boundary_ticks_once_per_frame() -> void:
	var fixture := _make_fixture(true)
	var controller: Object = fixture.controller
	var owner: FakeOwner = fixture.owner
	var registry: FakeRegistry = fixture.registry
	var runtime: Object = registry.mythic_runtime
	var boundary_gate: FakeBoundaryModalGate = registry.modal_gate
	runtime.start_acquisition_cinematic(_build_cinematic_item(false), Vector2(220.0, 330.0), owner, registry)

	boundary_gate.block = true
	_process_frame(controller, owner, registry, 0.25)
	_expect_elapsed(runtime, 0.25, "blocked side of the boundary should tick once")
	boundary_gate.block = false
	_process_frame(controller, owner, registry, 0.25)
	_expect_elapsed(runtime, 0.50, "open side of the boundary should use only the normal update path (delta x1)")
	_expect(registry.normal_update_driver.update_calls == 1, "open boundary frame should call the normal update driver exactly once")
	_cleanup_fixture(fixture)


func _make_fixture(use_boundary_gate: bool) -> Dictionary:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new()
	if use_boundary_gate:
		registry.modal_gate = FakeBoundaryModalGate.new()
	return {
		"controller": BattleSceneFrameController.new(),
		"owner": owner,
		"registry": registry,
	}


func _cleanup_fixture(fixture: Dictionary) -> void:
	var registry: FakeRegistry = fixture.registry
	var runtime: Object = registry.mythic_runtime
	var owner: FakeOwner = fixture.owner
	if runtime != null:
		runtime.reset_round(registry)
		runtime.acquisition_cinematic = null
	registry.clear_all()
	owner.free()


func _process_frame(controller: Object, owner: Object, registry: FakeRegistry, delta: float) -> void:
	owner.gameplay_frame_counter += 1
	controller.process_physics(
		delta,
		owner,
		registry,
		Callable(registry, "get_instance"),
		{
			"is_battle_initialized": Callable(self, "_return_true"),
			"is_stage_landing_intro_started": Callable(self, "_return_true"),
		}
	)


func _build_cinematic_item(for_angel: bool) -> Dictionary:
	var item: Dictionary = MythicItemCatalog.new().build_item_by_name("heavenly_cape")
	if for_angel:
		item["perk_id"] = "angel_blessing"
	return item


func _make_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _return_true() -> bool:
	return true


func _expect_phase(runtime: Object, expected: String, message: String) -> void:
	_expect(str(runtime.get_acquisition_cinematic_snapshot().get("phase", "")) == expected, message)


func _expect_elapsed(runtime: Object, expected: float, message: String) -> void:
	var elapsed := float(runtime.get_acquisition_cinematic_snapshot().get("elapsed", -1.0))
	_expect(absf(elapsed - expected) <= EPSILON, "%s (expected %.3f, got %.3f)" % [message, expected, elapsed])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
