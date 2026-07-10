extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const ANGEL_PERK_ID := "angel_blessing"
const MIN_CONFIRM_SECONDS := 3.0
const VIEW_SIZE := Vector2(760.0, 750.0)
const REQUIRED_FACADES := [
	"get_angel_blessing_acquisition_snapshot",
	"has_pending_angel_blessing_acquisition",
	"update_angel_blessing_acquisition",
	"on_angel_blessing_acquisition_cinematic_finished",
	"is_angel_blessing_modal_active",
	"handle_angel_blessing_input",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe: Object = RuntimePerkState.new()
	if not _require_facades(probe, REQUIRED_FACADES):
		_finish()
		return

	_verify_pending_does_not_block_but_active_modal_does()
	_verify_three_second_minimum_and_first_frame_arm()
	_verify_keyboard_mouse_touch_and_gamepad_confirmation()
	_finish()


func _verify_pending_does_not_block_but_active_modal_does() -> void:
	var fixture: Dictionary = _build_pending_fixture(3)
	var runtime: Object = fixture["runtime"]
	var getter := FakeCachedModuleGetter.new({"runtime_perk_state": runtime})
	var modal_gate := BattleSceneModalGateController.new()
	var module_getter := Callable(getter, "get_module")

	_expect(bool(runtime.call("has_pending_angel_blessing_acquisition")), "accepted Angel grant should expose pending work before presentation")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "pending Angel work alone must not report an active modal")
	_expect(not bool(modal_gate.should_block_battle_physics(module_getter)), "pending-only Angel work must not block battle physics")
	_expect(not bool(modal_gate.should_block_mobile_controls(module_getter)), "pending-only Angel work must not block mobile controls")

	_open_pending_modal(fixture)
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "ready Angel result should expose its dedicated active-modal facade")
	_expect(not runtime.is_choice_active(), "Angel presentation must not masquerade as the standard runtime perk choice")
	_expect(bool(modal_gate.should_block_battle_physics(module_getter)), "active Angel modal should block battle physics through the shared modal gate")
	_expect(bool(modal_gate.should_block_mobile_controls(module_getter)), "active Angel modal should block mobile controls through the shared modal gate")
	_expect(getter.lazy_keys.is_empty(), "Angel modal gate checks must use the cached runtime state without lazy creation")


func _verify_three_second_minimum_and_first_frame_arm() -> void:
	var fixture: Dictionary = _build_pending_fixture(4)
	var runtime: Object = fixture["runtime"]
	_open_pending_modal(fixture)
	var opened_snapshot: Dictionary = _snapshot(runtime)
	_expect(not bool(opened_snapshot.get("input_armed", true)), "Angel confirm must stay unarmed on the frame the modal opens")
	_expect(not bool(opened_snapshot.get("confirm_armed", true)), "Angel confirm must not be armed at zero elapsed time")

	var opening_press: InputEventKey = _key_event(KEY_ENTER, true)
	_expect(_handle(runtime, fixture, opening_press), "active Angel modal should consume its opening-frame confirm event")
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "opening-frame confirm must not cascade into Angel dismissal")

	_advance(fixture, 0.0)
	var next_frame_snapshot: Dictionary = _snapshot(runtime)
	_expect(bool(next_frame_snapshot.get("input_armed", false)), "Angel input should arm on the frame after opening")
	_handle(runtime, fixture, _key_event(KEY_ENTER, false))
	_advance(fixture, MIN_CONFIRM_SECONDS - 0.01)
	_expect(not bool(_snapshot(runtime).get("confirm_armed", true)), "Angel confirm must remain disabled before the three-second minimum")
	_handle(runtime, fixture, _key_event(KEY_ENTER, true))
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "Enter before three seconds must not dismiss Angel")
	_handle(runtime, fixture, _key_event(KEY_ENTER, false))

	_advance(fixture, 0.02)
	var ready_snapshot: Dictionary = _snapshot(runtime)
	_expect(float(ready_snapshot.get("modal_elapsed", 0.0)) >= MIN_CONFIRM_SECONDS, "Angel modal should expose at least three elapsed seconds before confirm")
	_expect(bool(ready_snapshot.get("confirm_armed", false)), "Angel confirm should arm after duration and input gates are both satisfied")
	_expect(_handle(runtime, fixture, _key_event(KEY_ENTER, true)), "ready Enter confirm should be consumed")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "fresh Enter after three seconds should dismiss Angel exactly once")
	_expect(not _handle(runtime, fixture, _key_event(KEY_ENTER, true)), "closed Angel modal must not consume duplicate held confirms")


func _verify_keyboard_mouse_touch_and_gamepad_confirmation() -> void:
	_verify_input_family(
		"Space",
		_key_event(KEY_SPACE, true),
		_key_event(KEY_SPACE, false),
		_key_event(KEY_SPACE, true)
	)
	_verify_input_family(
		"mouse left",
		_mouse_button_event(true),
		_mouse_button_event(false),
		_mouse_button_event(true)
	)
	_verify_input_family(
		"touch",
		_touch_event(true),
		_touch_event(false),
		_touch_event(true)
	)
	_verify_input_family(
		"gamepad A",
		_joy_button_event(true),
		_joy_button_event(false),
		_joy_button_event(true)
	)
	_verify_input_family(
		"gamepad RT",
		_rt_axis_event(0.80),
		_rt_axis_event(0.10),
		_rt_axis_event(0.80)
	)
	_verify_neutral_rt_first_press()


func _verify_neutral_rt_first_press() -> void:
	var fixture: Dictionary = _build_pending_fixture(6)
	var runtime: Object = fixture["runtime"]
	_open_pending_modal(fixture)
	_advance(fixture, MIN_CONFIRM_SECONDS + 0.01)
	_expect(
		_handle(runtime, fixture, _rt_axis_event(0.80)),
		"a fresh RT press from a neutral-open modal should be consumed"
	)
	_expect(
		not bool(runtime.call("is_angel_blessing_modal_active")),
		"a fresh RT press after three seconds should dismiss without a dummy release/second press"
	)


func _verify_input_family(
	label: String,
	held_press: InputEvent,
	release_event: InputEvent,
	fresh_press: InputEvent
) -> void:
	var fixture: Dictionary = _build_pending_fixture(5)
	var runtime: Object = fixture["runtime"]
	_open_pending_modal(fixture)
	_expect(_handle(runtime, fixture, held_press), "%s opening press should be consumed" % label)
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "%s opening press must not cascade" % label)

	_advance(fixture, MIN_CONFIRM_SECONDS + 0.01)
	_expect(_handle(runtime, fixture, release_event), "%s release should be consumed while Angel is active" % label)
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "%s release must not dismiss Angel" % label)
	_expect(_handle(runtime, fixture, fresh_press), "%s fresh press should confirm after release" % label)
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "%s should dismiss Angel once after release and fresh press" % label)


func _build_pending_fixture(stage: int) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	var owner := FakeOwner.new(stage)
	root.add_child(owner)
	var cinematic := FakeMythicRuntime.new()
	var catalog := FakeCatalog.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"mythic_item_runtime": cinematic,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"smasher_skill_state": SmasherSkillState.new(),
	})
	runtime.set("current_choice_context", {"source": "battle_mythic_jackpot", "grant_scope": "battle"})
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "modal fixture should accept the first Angel acquisition")
	_expect(_pending_roll_count(runtime) == 1, "modal fixture should queue one current-stage roll")
	return {
		"runtime": runtime,
		"owner": owner,
		"registry": registry,
		"cinematic": cinematic,
	}


func _open_pending_modal(fixture: Dictionary) -> void:
	var runtime: Object = fixture["runtime"]
	# The real mythic runtime emits this callback only after its cinematic has
	# transitioned to inactive. The dedicated Angel icon now lets this fixture
	# start that cinematic for real, so mirror the production callback ordering.
	var cinematic: Object = fixture.get("cinematic", null)
	if cinematic != null:
		cinematic.set("active", false)
	runtime.call("on_angel_blessing_acquisition_cinematic_finished", ANGEL_PERK_ID)
	_advance(fixture, 0.0)
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "ready pending roll should open the Angel modal")


func _advance(fixture: Dictionary, delta: float) -> Dictionary:
	var runtime: Object = fixture["runtime"]
	var value: Variant = runtime.callv(
		"update_angel_blessing_acquisition",
		[
			delta,
			fixture["owner"],
			fixture["registry"],
			{},
			{
				"forced_face": 1,
				"forced_candidate_order": ["move_speed"],
			},
		]
	)
	return _as_dictionary(value)


func _handle(runtime: Object, fixture: Dictionary, event: InputEvent) -> bool:
	return bool(runtime.callv(
		"handle_angel_blessing_input",
		[event, fixture["owner"], fixture["registry"], VIEW_SIZE]
	))


func _snapshot(runtime: Object) -> Dictionary:
	return _as_dictionary(runtime.call("get_angel_blessing_acquisition_snapshot"))


func _pending_roll_count(runtime: Object) -> int:
	var pending_value: Variant = _snapshot(runtime).get("pending_rolls", [])
	return (pending_value as Array).size() if pending_value is Array else 0


func _angel_choice() -> Dictionary:
	return {
		"id": ANGEL_PERK_ID,
		"perk_id": ANGEL_PERK_ID,
		"name": "천사의 가호",
		"max_level": 1,
		"rarity": "mythic",
		"tree": "mythic",
		"description": "스테이지마다 천사의 주사위를 굴립니다.",
		"descriptions": {1: "스테이지마다 천사의 주사위를 굴립니다."},
	}


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _mouse_button_event(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = VIEW_SIZE * 0.5
	return event


func _touch_event(pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = VIEW_SIZE * 0.5
	return event


func _joy_button_event(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


func _rt_axis_event(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _require_facades(runtime: Object, names: Array) -> bool:
	var complete := true
	for name_value: Variant in names:
		var method_name: String = str(name_value)
		if runtime.has_method(method_name):
			continue
		complete = false
		_failures.append("missing RuntimePerkState S4 facade: %s" % method_name)
	return complete


func _as_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_modal_smoke: ok")
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

	func _init(stage: int) -> void:
		current_stage = stage

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeMythicRuntime:
	extends RefCounted

	var active := false

	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		active = true
		return true

	func is_acquisition_cinematic_active() -> bool:
		return active

	func refresh_runtime_perk_scaling(_owner: Object = null, _registry: Object = null) -> void:
		pass


class FakeCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		return _perk_data() if perk_id == ANGEL_PERK_ID else {}

	func has_open_perk_slot(_runtime_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_slot_status(_runtime_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return {"count": 0, "limit": 8, "is_full": false}

	func _perk_data() -> Dictionary:
		return {
			"id": ANGEL_PERK_ID,
			"perk_id": ANGEL_PERK_ID,
			"name": "천사의 가호",
			"max_level": 1,
			"rarity": "mythic",
			"tree": "mythic",
			"description": "스테이지마다 천사의 주사위를 굴립니다.",
			"descriptions": {1: "스테이지마다 천사의 주사위를 굴립니다."},
		}


class FakeCachedModuleGetter:
	extends RefCounted

	var cached: Dictionary
	var lazy_keys: Array[String] = []

	func _init(source: Dictionary) -> void:
		cached = source

	func _get_cached_module(key: String) -> Object:
		return _as_object(cached.get(key, null))

	func get_module(key: String) -> Object:
		lazy_keys.append(key)
		return _as_object(cached.get(key, null))

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null
