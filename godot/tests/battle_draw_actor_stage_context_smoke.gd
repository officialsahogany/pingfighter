extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/core/battle_draw_actor_stage_context.gd"
const FACADE_PATH := "res://scripts/core/battle_draw_actor_context.gd"

var _failures: Array[String] = []


class DrawState:
	extends RefCounted

	var label: String
	var payload: Dictionary
	var calls: Array

	func _init(next_label: String, next_payload: Dictionary, call_log: Array) -> void:
		label = next_label
		payload = next_payload
		calls = call_log

	func get_draw_context() -> Dictionary:
		calls.append(label)
		return payload


class ActorState:
	extends RefCounted

	var label: String
	var payload: Dictionary
	var calls: Array

	func _init(next_label: String, next_payload: Dictionary, call_log: Array) -> void:
		label = next_label
		payload = next_payload
		calls = call_log

	func get_actor_draw_context() -> Dictionary:
		calls.append(label)
		return payload


class GatedActorState:
	extends RefCounted

	var enabled: bool
	var payload: Dictionary
	var calls: Array

	func _init(next_enabled: bool, next_payload: Dictionary, call_log: Array) -> void:
		enabled = next_enabled
		payload = next_payload
		calls = call_log

	func has_actor_draw_context() -> bool:
		calls.append("fire_gate")
		return enabled

	func get_actor_draw_context() -> Dictionary:
		calls.append("fire_context")
		return payload


class HudState:
	extends RefCounted

	var label: String
	var payload: Dictionary
	var calls: Array

	func _init(next_label: String, next_payload: Dictionary, call_log: Array) -> void:
		label = next_label
		payload = next_payload
		calls = call_log

	func get_hud_context() -> Dictionary:
		calls.append(label)
		return payload


class Stage4MapState:
	extends RefCounted

	var payload: Dictionary
	var calls: Array
	var received_deps: Dictionary = {}

	func _init(next_payload: Dictionary, call_log: Array) -> void:
		payload = next_payload
		calls = call_log

	func get_actor_draw_context(deps: Dictionary) -> Dictionary:
		calls.append("stage4_map")
		received_deps = deps
		return payload


class ImpactEffects:
	extends RefCounted

	var calls: Array

	func _init(call_log: Array) -> void:
		calls = call_log

	func get_wall_border_flash_timer() -> float:
		calls.append("flash_timer")
		return 1.25

	func get_wall_border_flash_duration() -> float:
		calls.append("flash_duration")
		return 2.5

	func get_wall_border_flash_position() -> Vector2:
		calls.append("flash_position")
		return Vector2(12.0, 34.0)

	func get_wall_border_flash_side() -> String:
		calls.append("flash_side")
		return "left"

	func get_wall_border_flash_speed() -> float:
		calls.append("flash_speed")
		return 456.0


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		_verify_stage1_capture_and_merge()
		_verify_stage2_precedence_and_reset()
		_verify_stage4_dependency_and_flash_policy()
		_verify_stage5_gate_and_precedence()
		_verify_single_source_stages()
		_verify_production_facade_binding()

	if _failures.is_empty():
		print("battle_draw_actor_stage_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "stage actor sources should have a focused context owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(facade_source.contains("BattleDrawActorStageContext"), "actor context should preload the focused stage owner")
	_expect(facade_source.contains("stage_context.capture_sources("), "stage source reads should delegate")
	_expect(facade_source.contains("stage_context.merge_into(actor_context)"), "stage merge policy should delegate")
	_expect(not facade_source.contains("var stage2_context"), "actor facade should not retain concrete Stage 2 source state")
	_expect(not facade_source.contains("var stage7_akamu_context"), "actor facade should not retain concrete Stage 7 source state")
	_expect(not facade_source.contains("func _get_stage1_wall_flash_context"), "Stage 1 wall-flash projection should belong to the focused owner")
	_expect(not facade_source.contains("func _get_stage4_wall_flash_context"), "Stage 4 wall-flash projection should belong to the focused owner")
	var capture_index := facade_source.find("stage_context.capture_sources(")
	var item_source_index := facade_source.find("var active_item_runtime")
	var stage_merge_index := facade_source.find("stage_context.merge_into(actor_context)")
	var item_merge_index := facade_source.find("actor_context.merge(active_item_context")
	_expect(capture_index >= 0 and capture_index < item_source_index, "stage sources should still be read before item/status actor sources")
	_expect(stage_merge_index >= 0 and stage_merge_index < item_merge_index, "stage contexts should still merge before item/status contexts")
	_expect(owner_source.contains("func capture_sources("), "focused owner should expose source capture")
	_expect(owner_source.contains("func merge_into("), "focused owner should expose allocation-neutral merge")


func _verify_stage1_capture_and_merge() -> void:
	var calls: Array = []
	var owner: Object = _new_owner()
	owner.capture_sources(1, "dalji", {
		"stage1_dalji_whip_skill_state": DrawState.new("whip", {"stage_order": "whip", "whip": true}, calls),
		"stage1_dalji_spinning_top_skill_state": DrawState.new("top", {"stage_order": "top", "top": true}, calls),
		"stage1_dalji_boss_skill_cooldown_state": HudState.new("cooldown", {"stage_order": "cooldown", "cooldown": true}, calls),
		"impact_effects": ImpactEffects.new(calls),
	})
	var output := {"stage_order": "base"}
	owner.merge_into(output)
	_expect(calls == ["whip", "top", "cooldown", "flash_timer", "flash_duration", "flash_position", "flash_side", "flash_speed"], "Stage 1 source reads should preserve production order")
	_expect(output.get("stage_order") == "cooldown", "Stage 1 cooldown context should retain last-writer priority")
	_expect(bool(output.get("whip", false)) and bool(output.get("top", false)), "Stage 1 skill payloads should both merge")
	_expect(is_equal_approx(float(output.get("stage1_wall_flash_timer", 0.0)), 1.25), "Stage 1 wall flash should retain timer projection")
	_expect(output.get("stage1_wall_flash_position") == Vector2(12.0, 34.0), "Stage 1 wall flash should retain position projection")

	var gaksi_calls: Array = []
	var fan_payload := {"shared": "throw", "fan_throw": true}
	owner.capture_sources(1, "gaksi", {
		"stage1_gaksital_fan_throw_skill_state": DrawState.new("fan_throw", fan_payload, gaksi_calls),
		"stage1_gaksital_fan_wind_skill_state": DrawState.new("fan_wind", {"shared": "wind", "fan_wind": true}, gaksi_calls),
		"stage1_gaksital_boss_skill_cooldown_state": HudState.new("gaksi_cooldown", {"shared": "cooldown"}, gaksi_calls),
	})
	var gaksi_output: Dictionary = {}
	owner.merge_into(gaksi_output)
	_expect(gaksi_calls == ["fan_throw", "fan_wind", "gaksi_cooldown"], "Gaksital source reads should preserve throw, wind, cooldown order")
	_expect(fan_payload.get("shared") == "wind", "Gaksital wind should retain the existing in-place merge into the throw snapshot")
	_expect(gaksi_output.get("shared") == "cooldown", "Gaksital cooldown should retain final Stage 1 priority")
	_expect(bool(gaksi_output.get("fan_throw", false)) and bool(gaksi_output.get("fan_wind", false)), "Gaksital throw and wind payloads should both survive")


func _verify_stage2_precedence_and_reset() -> void:
	var calls: Array = []
	var owner: Object = _new_owner()
	owner.capture_sources(2, "dalji", {
		"stage2_pillar_background": ActorState.new("stage2_background", {"shared": "background", "stage2_background": true}, calls),
		"stage2_boss_skill_state": ActorState.new("stage2_skill", {"shared": "skill", "stage2_skill": true}, calls),
	})
	var output: Dictionary = {}
	owner.merge_into(output)
	_expect(calls == ["stage2_background", "stage2_skill"], "Stage 2 source reads should preserve background-before-skill order")
	_expect(output.get("shared") == "skill", "Stage 2 skill context should retain last-writer priority")
	_expect(bool(output.get("stage2_background", false)) and bool(output.get("stage2_skill", false)), "Stage 2 contexts should both merge")

	owner.capture_sources(8, "dalji", {"stage8_minotaur_state": ActorState.new("stage8", {"stage8_only": true}, calls)})
	var reset_output: Dictionary = {}
	owner.merge_into(reset_output)
	_expect(not reset_output.has("stage2_background"), "capturing a new stage should clear stale Stage 2 payloads")
	_expect(bool(reset_output.get("stage8_only", false)), "capturing a new stage should publish only its current payload")


func _verify_stage4_dependency_and_flash_policy() -> void:
	var calls: Array = []
	var owner: Object = _new_owner()
	var map_state := Stage4MapState.new({"stage4_wall_flash_timer": 99.0, "map_payload": true}, calls)
	var dependency_tokens := {
		"stage4_temple_destruction_event": RefCounted.new(),
		"stage4_moon_event": RefCounted.new(),
		"stage4_bird_event": RefCounted.new(),
		"stage4_brazier_monk_event": RefCounted.new(),
		"stage4_ponk_skill_state": RefCounted.new(),
	}
	var deps := dependency_tokens.duplicate()
	deps["stage4_map_state"] = map_state
	deps["impact_effects"] = ImpactEffects.new(calls)
	owner.capture_sources(4, "dalji", deps)
	var output: Dictionary = {}
	owner.merge_into(output)
	_expect(calls == ["stage4_map", "flash_timer", "flash_duration", "flash_position", "flash_side", "flash_speed"], "Stage 4 map and wall-flash reads should preserve production order")
	for key in dependency_tokens:
		_expect(map_state.received_deps.get(key) == dependency_tokens[key], "Stage 4 map should receive the live %s dependency" % key)
	_expect(map_state.received_deps.size() == 5, "Stage 4 map should receive only its five established dependencies")
	_expect(is_equal_approx(float(output.get("stage4_wall_flash_timer", 0.0)), 1.25), "Stage 4 wall flash should overwrite a map collision like the facade did")


func _verify_stage5_gate_and_precedence() -> void:
	var calls: Array = []
	var owner: Object = _new_owner()
	var fire_state := GatedActorState.new(true, {"shared": "fire", "fire_machine": true}, calls)
	owner.capture_sources(5, "dalji", {
		"stage5_hongryun_state": ActorState.new("hongryun", {"shared": "stage", "hongryun": true}, calls),
		"stage5_hongryun_fire_machine_event": fire_state,
	})
	var output: Dictionary = {}
	owner.merge_into(output)
	_expect(calls == ["hongryun", "fire_gate", "fire_context"], "Stage 5 should read state before gated fire-machine context")
	_expect(output.get("shared") == "fire", "Stage 5 fire-machine context should retain last-writer priority")

	calls.clear()
	fire_state.enabled = false
	owner.capture_sources(5, "dalji", {
		"stage5_hongryun_state": ActorState.new("hongryun", {"shared": "stage"}, calls),
		"stage5_hongryun_fire_machine_event": fire_state,
	})
	var gated_output: Dictionary = {}
	owner.merge_into(gated_output)
	_expect(calls == ["hongryun", "fire_gate"], "disabled Stage 5 fire-machine context should not be materialized")
	_expect(gated_output.get("shared") == "stage", "disabled fire-machine context should leave the stage payload intact")


func _verify_single_source_stages() -> void:
	var cases := {
		3: ["stage3_boss_skill_state", "stage3"],
		6: ["stage6_tetriser_state", "stage6"],
		7: ["stage7_akamu_state", "stage7"],
		8: ["stage8_minotaur_state", "stage8"],
	}
	for stage in cases:
		var calls: Array = []
		var spec: Array = cases[stage]
		var owner: Object = _new_owner()
		owner.capture_sources(stage, "dalji", {spec[0]: ActorState.new(spec[1], {spec[1]: true}, calls)})
		var output: Dictionary = {}
		owner.merge_into(output)
		_expect(calls == [spec[1]], "Stage %d should read its single actor source once" % stage)
		_expect(bool(output.get(spec[1], false)), "Stage %d should merge its actor payload" % stage)


func _verify_production_facade_binding() -> void:
	var calls: Array = []
	var facade_script: Script = load(FACADE_PATH)
	var facade: Object = facade_script.new()
	var output: Dictionary = facade.build({
		"current_stage": 5,
		"selected_character_type": "smasher",
		"textures": {},
		"player_pos": Vector2(100.0, 700.0),
		"player_paddle_size": Vector2(100.0, 24.0),
		"boss_pos": Vector2(330.0, 20.0),
		"boss_paddle_size": Vector2(100.0, 24.0),
	}, {
		"stage5_hongryun_state": ActorState.new("hongryun", {"production_stage": "state"}, calls),
		"stage5_hongryun_fire_machine_event": GatedActorState.new(true, {"production_stage": "fire"}, calls),
	})
	_expect(calls == ["hongryun", "fire_gate", "fire_context"], "production actor facade should invoke the focused owner once in established order")
	_expect(output.get("production_stage") == "fire", "production actor facade should preserve Stage 5 merge priority")


func _new_owner() -> Object:
	var owner_script: Script = load(OWNER_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
