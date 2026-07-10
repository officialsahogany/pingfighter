extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const ANGEL_PERK_ID := "angel_blessing"
const VIEW_SIZE := Vector2(760.0, 750.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_angel_work_only_overlay_pump_uses_live_state()
	_verify_input_priority_chain()
	_verify_result_and_scoreboard_hold_ready_current_stage_work()
	_finish()


func _verify_angel_work_only_overlay_pump_uses_live_state() -> void:
	var owner := FakeOwner.new(3)
	root.add_child(owner)
	var runtime := FakeOverlayRuntimePerkState.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"runtime_perk_state": runtime,
	})
	var controller := BattleSceneOverlayFrameController.new()
	var module_getter := Callable(registry, "get_instance")
	var blocked: bool = controller.process_idle(
		0.25,
		owner,
		registry,
		module_getter
	)

	_expect(runtime.update_count == 1, "Angel-work-only overlay path should pump RuntimePerkState.update exactly once")
	_expect(
		controller.has_blocking_activity(module_getter),
		"a live Angel modal should suppress skill/drive cut-ins through the shared overlay activity gate"
	)
	_expect(runtime.angel_modal_active, "overlay fixture should activate Angel during the update call")
	_expect(blocked, "overlay controller should use live post-update Angel state and return blocking true")
	_expect(
		owner.redraws == 0,
		"Angel-work-only overlay update should redraw only its detached host, not the full battle shell"
	)
	owner.free()


func _verify_input_priority_chain() -> void:
	_verify_input_priority_case("runtime choice", true, true, true, true, "overlay")
	_verify_input_priority_case("mythic acquisition", false, true, true, true, "acquisition")
	_verify_input_priority_case("Pandora", false, false, true, true, "pandora")
	_verify_input_priority_case("Angel", false, false, false, true, "angel")
	_verify_input_priority_case("ordinary overlay", false, false, false, false, "overlay")


func _verify_input_priority_case(
	label: String,
	choice_active: bool,
	acquisition_active: bool,
	pandora_active: bool,
	angel_active: bool,
	expected_consumer: String
) -> void:
	var owner := FakeOwner.new(3)
	var runtime := FakeInputRuntimePerkState.new()
	runtime.choice_active = choice_active
	runtime.angel_modal_active = angel_active
	var mythic := FakeMythicItemRuntime.new()
	mythic.acquisition_active = acquisition_active
	mythic.pandora_active = pandora_active
	var overlay := FakeOverlayInputController.new()
	var readiness := FakeReadinessController.new()
	var registry := FakeRegistry.new({
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"battle_scene_overlay_input_controller": overlay,
		"battle_scene_readiness_controller": readiness,
		"runtime_perk_state": runtime,
		"mythic_item_runtime": mythic,
	})

	BattleSceneInputController.new().handle_unhandled_input(
		_mouse_click(),
		owner,
		registry,
		Callable(registry, "get_instance"),
		{
			"battle_initialized": true,
			"stage_landing_intro_started": true,
			"mobile_touch_scene_ready": true,
		}
	)

	var counts := {
		"overlay": overlay.input_count,
		"acquisition": mythic.acquisition_input_count,
		"pandora": mythic.pandora_input_count,
		"angel": runtime.angel_input_count,
	}
	for consumer: String in counts:
		var expected_count := 1 if consumer == expected_consumer else 0
		_expect(
			int(counts[consumer]) == expected_count,
			"%s priority should route only to %s (unexpected %s count: %d)" % [
				label,
				expected_consumer,
				consumer,
				int(counts[consumer]),
			]
		)
	owner.free()


func _verify_result_and_scoreboard_hold_ready_current_stage_work() -> void:
	var owner := FakeOwner.new(6)
	root.add_child(owner)
	var runtime: Object = RuntimePerkState.new()
	var mythic := FakeMythicItemRuntime.new()
	var result_screen := FakeActiveState.new()
	var scoreboard := FakeActiveState.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": FakeCatalog.new(),
		"mythic_item_runtime": mythic,
		"stage_clear_result_screen": result_screen,
		"scoreboard_state": scoreboard,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"smasher_skill_state": SmasherSkillState.new(),
	})
	runtime.set("current_choice_context", {
		"source": "battle_mythic_jackpot",
		"grant_scope": "battle",
	})
	_expect(
		bool(runtime.call("apply_choice", _angel_choice(), owner, registry)),
		"fixture should accept the first battle-time Angel acquisition"
	)
	mythic.acquisition_active = false
	runtime.call("on_angel_blessing_acquisition_cinematic_finished", ANGEL_PERK_ID)
	_expect(_ready_current_stage_roll_count(runtime) == 1, "cinematic completion should leave one ready current-stage Angel roll")

	result_screen.active = true
	_advance_angel(runtime, owner, registry)
	_expect(_ready_current_stage_roll_count(runtime) == 1, "active stage-clear result screen must preserve ready Angel work")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal must stay closed behind the result screen")

	result_screen.active = false
	scoreboard.active = true
	_advance_angel(runtime, owner, registry)
	_expect(_ready_current_stage_roll_count(runtime) == 1, "active scoreboard must preserve ready Angel work")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal must stay closed behind the scoreboard")

	scoreboard.active = false
	_advance_angel(runtime, owner, registry)
	_expect(_ready_current_stage_roll_count(runtime) == 0, "ready Angel work should be consumed after both blockers close")
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal should open after result screen and scoreboard are both inactive")
	owner.free()


func _advance_angel(runtime: Object, owner: Object, registry: Object) -> void:
	runtime.callv(
		"update_angel_blessing_acquisition",
		[
			0.0,
			owner,
			registry,
			{},
			{
				"forced_face": 1,
				"forced_candidate_order": ["move_speed"],
			},
		]
	)


func _ready_current_stage_roll_count(runtime: Object) -> int:
	var snapshot_value: Variant = runtime.call("get_angel_blessing_acquisition_snapshot")
	if not (snapshot_value is Dictionary):
		return 0
	var pending_value: Variant = (snapshot_value as Dictionary).get("pending_rolls", [])
	if not (pending_value is Array):
		return 0
	var count := 0
	for entry_value: Variant in pending_value:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if (
			str(entry.get("policy", "")) == "current_stage"
			and bool(entry.get("ready", false))
			and not bool(entry.get("waiting_for_cinematic", false))
		):
			count += 1
	return count


func _angel_choice() -> Dictionary:
	return {
		"id": ANGEL_PERK_ID,
		"perk_id": ANGEL_PERK_ID,
		"name": "Angel Blessing",
		"max_level": 1,
		"rarity": "mythic",
		"tree": "mythic",
		"description": "Roll Angel's Dice at each valid stage.",
		"descriptions": {1: "Roll Angel's Dice at each valid stage."},
	}


func _mouse_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = VIEW_SIZE * 0.5
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_s4_controller_wiring_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


class FakeOwner:
	extends Node

	var current_stage := 1
	var arena_mode_enabled := false
	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var runtime_perk_gold := 0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var redraws := 0

	func _init(stage: int) -> void:
		current_stage = stage

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, VIEW_SIZE)

	func queue_redraw() -> void:
		redraws += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func get_cached_instance(key: String) -> Object:
		return _as_object(instances.get(key, null))

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakeOverlayRuntimePerkState:
	extends RefCounted

	var angel_modal_active := false
	var update_count := 0

	func is_choice_active() -> bool:
		return false

	func has_feedback() -> bool:
		return false

	func has_angel_blessing_modal_work() -> bool:
		return true

	func is_angel_blessing_modal_active() -> bool:
		return angel_modal_active

	func update(_delta: float, _view_size: Vector2, _owner: Object, _registry: Object) -> void:
		update_count += 1
		angel_modal_active = true


class FakeInputRuntimePerkState:
	extends RefCounted

	var choice_active := false
	var angel_modal_active := false
	var angel_input_count := 0

	func is_choice_active() -> bool:
		return choice_active

	func is_angel_blessing_modal_active() -> bool:
		return angel_modal_active

	func handle_angel_blessing_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		angel_input_count += 1
		return true


class FakeMythicItemRuntime:
	extends RefCounted

	var acquisition_active := false
	var pandora_active := false
	var acquisition_input_count := 0
	var pandora_input_count := 0

	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		acquisition_active = true
		return true

	func is_acquisition_cinematic_active() -> bool:
		return acquisition_active

	func handle_acquisition_cinematic_input(_event: InputEvent, _registry: Object = null) -> bool:
		acquisition_input_count += 1
		return true

	func is_pandora_legacy_selection_active() -> bool:
		return pandora_active

	func handle_pandora_legacy_selection_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_view_size: Vector2
	) -> bool:
		pandora_input_count += 1
		return true

	func is_debug_management_menu_open() -> bool:
		return false

	func refresh_runtime_perk_scaling(_owner: Object = null, _registry: Object = null) -> void:
		pass


class FakeOverlayInputController:
	extends RefCounted

	var input_count := 0

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_context: Dictionary
	) -> bool:
		input_count += 1
		return true


class FakeReadinessController:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_battle_initialized: bool,
		_stage_landing_intro_started: bool
	) -> bool:
		return false


class FakeActiveState:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id != ANGEL_PERK_ID:
			return {}
		return {
			"id": ANGEL_PERK_ID,
			"perk_id": ANGEL_PERK_ID,
			"name": "Angel Blessing",
			"max_level": 1,
			"rarity": "mythic",
			"tree": "mythic",
			"description": "Roll Angel's Dice at each valid stage.",
			"descriptions": {1: "Roll Angel's Dice at each valid stage."},
		}

	func has_open_perk_slot(_runtime_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_slot_status(_runtime_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return {"count": 0, "limit": 8, "is_full": false}
