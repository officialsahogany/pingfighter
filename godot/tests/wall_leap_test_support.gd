extends RefCounted

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const ViperSkillState := preload("res://scripts/characters/viper_skill_state.gd")


class InputProbe:
	extends RefCounted
	var snapshot: Dictionary = {}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class DashProbe:
	extends RefCounted
	var active := false
	var recovering := false
	func get_snapshot() -> Dictionary:
		return {"active": active, "recovering": recovering}


class JetpackProbe:
	extends RefCounted
	var airborne := false
	func is_airborne(_minimum_height: float = 0.0) -> bool:
		return airborne


class FreezeProbe:
	extends RefCounted
	var active := false
	func is_freeze_active() -> bool:
		return active


class RoundProbe:
	extends RefCounted
	var waiting := false
	func is_waiting_for_serve() -> bool:
		return waiting


class StatusProbe:
	extends RefCounted
	var calls: Array[Dictionary] = []
	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var entry := {"target": target, "status_id": status_id, "duration_frames": duration_frames, "data": data.duplicate(true), "source": source}
		calls.append(entry)
		return entry
	func is_player_stun_active() -> bool:
		return false
	func has_status(_target: String, _status_id: String) -> bool:
		return false


class AudioProbe:
	extends RefCounted
	var entry_or_return_count := 0
	var slash_count := 0
	var blast_count := 0
	func play_viper_backstep() -> void:
		entry_or_return_count += 1
	func play_paddle_hit(_source_x: float = 380.0) -> void:
		pass
	func play_viper_venom_attack() -> void:
		slash_count += 1
	func play_grenade_explosion() -> void:
		blast_count += 1
	func play_stage3_psychoball_loop() -> void:
		pass
	func stop_stage3_psychoball_loop() -> void:
		pass
	func sync_stage3_psychoball_loop(_active: bool) -> void:
		pass


class OrbProbe:
	extends RefCounted
	var spins := 0
	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FeedbackProbe:
	extends RefCounted
	var flashes := 0
	func trigger_gauge_flash() -> void:
		flashes += 1


class RegistryProbe:
	extends RefCounted
	var instances: Dictionary = {}
	var cached_reads := 0
	var cold_reads := 0
	func get_cached_instance(key: String) -> Object:
		cached_reads += 1
		return instances.get(key, null)
	func get_instance(key: String) -> Object:
		cold_reads += 1
		return instances.get(key, null)


class DynamicOwner:
	extends RefCounted
	var values: Dictionary = {
		"selected_character_type": "viper",
		"ball_active": true,
		"special_gauge": 500.0,
		"player_pos": Vector2(300.0, 680.0),
		"player_speed": 0.0,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(327.5, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(377.5, 680.0),
		"ball_vel": Vector2(0.0, 9.0),
		"ball_size": 28.6,
		"width": 760.0,
		"height": 750.0,
	}
	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)
	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


func make_fixture(gauge: float = 500.0) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var skill_config: Object = ViperSkillConfig.new()
	skill_config.equipped_skills = ["wall_leap_raid"]
	var skill_state: Object = ViperSkillState.new()
	var input := InputProbe.new()
	var dash := DashProbe.new()
	var jetpack := JetpackProbe.new()
	var power := FreezeProbe.new()
	var round_state := RoundProbe.new()
	var status := StatusProbe.new()
	var audio := AudioProbe.new()
	var orb := OrbProbe.new()
	var feedback := FeedbackProbe.new()
	var owner := DynamicOwner.new()
	owner.values["special_gauge"] = gauge
	var registry := RegistryProbe.new()
	registry.instances = {
		"viper_skill_runtime": runtime,
		"viper_skill_config": skill_config,
		"viper_skill_state": skill_state,
		"smasher_dash_state": dash,
		"viper_jetpack_state": jetpack,
		"smasher_power_smash_state": power,
		"round_flow_state": round_state,
		"status_effect_state": status,
		"game_audio": audio,
	}
	var deps := {
		"registry": registry,
		"viper_skill_runtime": runtime,
		"input_reader": input,
		"viper_skill_config": skill_config,
		"viper_skill_state": skill_state,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"dash_state": dash,
		"viper_jetpack_state": jetpack,
		"ball_power_freeze_state": power,
		"round_state": round_state,
		"status_effect_state": status,
		"audio": audio,
		"orb_hud_state": orb,
		"feedback": feedback,
	}
	return {
		"runtime": runtime,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"input": input,
		"dash": dash,
		"jetpack": jetpack,
		"power": power,
		"round": round_state,
		"status": status,
		"audio": audio,
		"orb": orb,
		"feedback": feedback,
		"owner": owner,
		"registry": registry,
		"deps": deps,
		"context": base_context(),
		"player_pos": Vector2(300.0, 680.0),
		"special_gauge": gauge,
	}


func base_context() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"waiting_for_serve": false,
		"width": 760.0,
		"height": 750.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_speed": 4.0,
		"boss_pos": Vector2(327.5, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_paddle_size": Vector2(100.0, 40.0),
	}


func enter(fixture: Dictionary) -> Dictionary:
	var input: InputProbe = fixture["input"]
	input.snapshot = {"secondary_action_pressed": true, "secondary_action_just_pressed": true}
	var result: Dictionary = _route(fixture, 1.0 / 60.0)
	input.snapshot = {}
	return result


func advance_to_infiltrating(fixture: Dictionary) -> void:
	for _index in range(14):
		_route(fixture, 1.0 / 60.0)


func advance_frames(fixture: Dictionary, frame_count: int, snapshot: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for index in range(frame_count):
		(fixture["input"] as InputProbe).snapshot = snapshot if index == 0 else _held_only(snapshot)
		result = _route(fixture, 1.0 / 60.0)
	(fixture["input"] as InputProbe).snapshot = {}
	return result


func route_once(fixture: Dictionary, snapshot: Dictionary = {}, delta: float = 1.0 / 60.0) -> Dictionary:
	(fixture["input"] as InputProbe).snapshot = snapshot
	var result := _route(fixture, delta)
	(fixture["input"] as InputProbe).snapshot = _held_only(snapshot)
	return result


func _route(fixture: Dictionary, delta: float) -> Dictionary:
	var runtime: Object = fixture["runtime"]
	var result: Dictionary = runtime.try_activate_before_movement(
		delta,
		fixture["player_pos"],
		fixture["special_gauge"],
		fixture["context"],
		fixture["deps"]
	)
	if result.has("player_pos"):
		fixture["player_pos"] = result["player_pos"]
	if result.has("special_gauge"):
		fixture["special_gauge"] = float(result["special_gauge"])
	return result


func _held_only(snapshot: Dictionary) -> Dictionary:
	var held := snapshot.duplicate(true)
	for key in ["secondary_action_just_pressed", "mouse_left_just_pressed", "primary_pointer_just_pressed"]:
		held[key] = false
	return held
