extends SceneTree

# Regression: Commando + Soul Burst (passive knee item) must spend special_gauge
# when dashing with zero dash tokens. The Commando controller delegates movement
# to the shared (Smasher) dash controller, which consumes the Soul Burst gauge,
# but Commando used to overwrite the returned special_gauge with its pre-dash
# value, silently discarding the spend. See commando_player_controller.update.

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const ResultApplier := preload("res://scripts/core/battle_scene_actor_update_result_applier.gd")


# Schema-gated owner mirroring battle_scene_shell -> battle_scene_state: a write
# to a key absent from DEFAULT_VALUES silently no-ops, so this catches the real
# owner-write path (a plain dict owner would hide schema-drop bugs).
class SchemaGatedOwner:
	extends RefCounted
	var scene_state: Object = BattleSceneState.new()
	func _init() -> void:
		scene_state.reset()
	func _get(p: StringName) -> Variant:
		var k := str(p)
		return scene_state.get_value(k) if scene_state.has_key(k) else null
	func _set(p: StringName, v: Variant) -> bool:
		var k := str(p)
		if not scene_state.has_key(k):
			return false
		scene_state.set_value(k, v)
		return true
	func queue_redraw() -> void:
		pass


class FakeInputReader:
	extends RefCounted
	var snap: Dictionary = {}
	func get_snapshot() -> Dictionary:
		return snap


class FakeRegistry:
	extends RefCounted
	var runtime: Object
	var dash_state: Object
	func _init(r: Object, d: Object) -> void:
		runtime = r
		dash_state = d
	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		if key == "smasher_dash_state":
			return dash_state
		return null
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var dash_state: Object = SmasherDashState.new()
	var owner := SchemaGatedOwner.new()
	var registry := FakeRegistry.new(runtime, dash_state)

	owner.set("special_gauge", 200.0)
	var acquire_index: int = runtime.acquire_item(
		"soul_burst", owner, registry, {"soul_burst_gauge_cost": 140.0}, true
	)
	_expect(acquire_index >= 0, "Soul Burst should equip onto the Commando owner")
	_expect(runtime.is_soul_burst_equipped(), "Soul Burst should report equipped")

	# Empty dash tokens so the dash must fall back to the Soul Burst gauge spend.
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	dash_state.dash_key_released_since_last = true
	owner.set("special_gauge", 200.0)

	var controller := CommandoPlayerController.new()
	var applier := ResultApplier.new()
	var input_reader := FakeInputReader.new()
	input_reader.snap = {
		"down_pressed": true,
		"left_pressed": false,
		"right_pressed": true,
		"direction": 1.0,
	}
	var deps := {
		"dash_state": dash_state,
		"registry": registry,
		"owner": owner,
		"mythic_item_runtime": runtime,
		"input_reader": input_reader,
		"selected_character_type": "soldier",
	}
	var config := {
		"special_gauge": float(owner.get("special_gauge")),
		"selected_character_type": "soldier",
		"paddle_width": 155.0, "paddle_height": 50.0,
		"play_left": 0.0, "play_right": 760.0,
		"paddle_speed": 4.0, "paddle_max_speed": 4.0,
		"paddle_accel": 0.38, "paddle_decel": 0.38,
	}

	var result: Dictionary = controller.update(
		1.0 / 60.0,
		int(owner.get("gameplay_frame_counter")),
		owner.get("player_pos"),
		float(owner.get("player_speed")),
		config,
		deps
	)
	applier.apply_player_result(owner, registry, result)

	_expect(bool(dash_state.get_snapshot().get("active", false)), "Soul Burst should start a real Commando dash")
	_expect(
		is_equal_approx(float(result.get("special_gauge", -1.0)), 60.0),
		"Commando dash result should carry the Soul Burst gauge spend (200 - 140 = 60), got %s" % str(result.get("special_gauge"))
	)
	_expect(
		is_equal_approx(float(owner.get("special_gauge")), 60.0),
		"Commando Soul Burst dash must spend special_gauge on the owner (expected 60), got %s" % str(owner.get("special_gauge"))
	)

	print("commando_soul_burst_dash_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
