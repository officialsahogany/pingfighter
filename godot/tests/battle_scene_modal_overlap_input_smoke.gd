extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const TowerRewardPickState := preload("res://scripts/tower_ascent/tower_reward_pick_state.gd")
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraws := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

	func queue_redraw() -> void:
		redraws += 1


class FakeReadiness:
	extends RefCounted

	func is_intro_or_warmup_blocking(_module_getter: Callable, _battle_initialized: bool, _stage_landing_intro_started: bool) -> bool:
		return false


class FakeRuntimePerkState:
	extends RefCounted

	var active := false
	var input_count := 0

	func is_choice_active() -> bool:
		return active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		input_count += 1
		return true


class FakeMythicItemRuntime:
	extends RefCounted

	var active := false
	var input_count := 0

	func is_acquisition_cinematic_active() -> bool:
		return active

	func handle_acquisition_cinematic_input(_event: InputEvent, _registry: Object = null) -> bool:
		input_count += 1
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


func _init() -> void:
	_verify_runtime_perk_choice_beats_mythic_acquisition_input()
	_verify_reward_pick_yields_to_mythic_acquisition()
	_verify_reward_pick_reclaims_input_after_mythic_acquisition()

	if _failures.is_empty():
		print("battle_scene_modal_overlap_input_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_perk_choice_beats_mythic_acquisition_input() -> void:
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	perk_state.active = true
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.active = true
	var fixture := _build_reward_pick_fixture(perk_state, mythic_runtime)
	var registry: FakeRegistry = fixture.registry

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(Vector2(300.0, 300.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		_context()
	)

	_expect(perk_state.input_count == 1, "runtime perk choice should receive click input while mythic acquisition is also active")
	_expect(mythic_runtime.input_count == 0, "mythic acquisition cinematic should not starve an active runtime perk choice")
	_expect(owner.redraws >= 1, "overlap input should request a redraw after routing to the perk modal")
	_dispose_reward_pick_fixture(fixture)


func _verify_reward_pick_yields_to_mythic_acquisition() -> void:
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	perk_state.active = false
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.active = true
	var fixture := _build_reward_pick_fixture(perk_state, mythic_runtime)
	var registry: FakeRegistry = fixture.registry
	var reward_state: Object = fixture.reward_state

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(Vector2(300.0, 300.0)),
		owner,
		registry,
		Callable(registry, "get_instance"),
		_context()
	)

	_expect(perk_state.input_count == 0, "closed runtime perk choice should not consume mythic acquisition clicks")
	_expect(reward_state.selected_index == 0, "reward pick must yield while its mythic acquisition modal is active")
	_expect(mythic_runtime.input_count == 1, "mythic acquisition must receive the click yielded by reward pick")
	_expect(
		BattleSceneModalGateController.new().should_block_battle_physics(Callable(registry, "get_instance")),
		"active mythic acquisition must join the production physics modal gate"
	)
	_expect(owner.redraws >= 1, "mythic acquisition input should still request redraw")
	_dispose_reward_pick_fixture(fixture)


func _verify_reward_pick_reclaims_input_after_mythic_acquisition() -> void:
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.active = false
	var fixture := _build_reward_pick_fixture(perk_state, mythic_runtime)
	var registry: FakeRegistry = fixture.registry
	var reward_state: Object = fixture.reward_state

	BattleSceneInputController.new().handle_unhandled_input(
		_key_press(KEY_RIGHT),
		owner,
		registry,
		Callable(registry, "get_instance"),
		_context()
	)

	_expect(reward_state.selected_index == 1, "reward pick must reclaim input after the cinematic closes")
	_expect(mythic_runtime.input_count == 0, "closed mythic acquisition must not receive reward-pick input")
	_expect(
		not BattleSceneModalGateController.new().should_block_battle_physics(Callable(registry, "get_instance")),
		"closed mythic acquisition must leave the production physics modal gate"
	)
	_dispose_reward_pick_fixture(fixture)


func _build_reward_pick_fixture(
	perk_state: Object,
	mythic_runtime: Object
) -> Dictionary:
	var reward_state := TowerRewardPickState.new()
	reward_state.active = true
	reward_state.choices.assign([{}, {}])
	reward_state.spent_flags.assign([false, false])
	var loot_state := VictoryLootPhaseState.new()
	loot_state.active = true
	loot_state.set("_reward_pick_state", reward_state)
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"battle_scene_overlay_input_controller": BattleSceneOverlayInputController.new(),
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"runtime_perk_state": perk_state,
		"mythic_item_runtime": mythic_runtime,
		"victory_loot_phase_state": loot_state,
	})
	reward_state.set("_registry", registry)
	return {"registry": registry, "reward_state": reward_state, "loot_state": loot_state}


func _dispose_reward_pick_fixture(fixture: Dictionary) -> void:
	var loot_state: Object = fixture.get("loot_state")
	if loot_state != null:
		loot_state.reset()


func _context() -> Dictionary:
	return {
		"battle_initialized": true,
		"stage_landing_intro_started": true,
		"mobile_touch_scene_ready": true,
	}


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
