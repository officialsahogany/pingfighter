extends SceneTree

const StageClearResultStarpointChoiceHandler := preload("res://scripts/core/stage_clear_result_starpoint_choice_handler.gd")

var _failures: Array[String] = []


class FakeScene:
	extends Control

	var _boxes: Array = [
		{
			"kind": "normal",
			"state": "opened",
			"reward": {
				"type": "starpoint",
				"amount": 1,
			},
		},
	]
	var _scene_field_name_lookup: Dictionary = {}
	var _starpoint_choice_gate_active: bool = false
	var _starpoint_choice_gate_box_index: int = -1


class FakeRuntimePerkState:
	extends RefCounted

	var choice_active: bool = false
	var open_calls: int = 0
	var update_calls: int = 0
	var selected_choice_sequence: int = 0
	var pending_skill_choices: int = 0
	var last_selected_character_type: String = ""
	var last_choice_context: Dictionary = {}
	var last_view_size: Vector2 = Vector2.ZERO
	var last_selected_choice: Dictionary = {
		"id": "dash_module_control",
		"name": "Module Control",
		"current_level": 0,
		"next_level": 1,
		"level_delta": 1,
	}

	func open_next_choice(
		selected_character_type: String,
		_runtime_perk_catalog: Object,
		_immediate: bool,
		_owner: Object,
		_registry: Object,
		_icon_renderer: Object = null,
		choice_context: Dictionary = {}
	) -> void:
		open_calls += 1
		last_selected_character_type = selected_character_type
		last_choice_context = choice_context.duplicate(true)
		choice_active = true
		pending_skill_choices = 1

	func is_choice_active() -> bool:
		return choice_active

	func update(_delta: float, view_size: Vector2, _owner: Object, _registry: Object) -> void:
		update_calls += 1
		last_view_size = view_size

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": {},
			"last_selected_id": str(last_selected_choice.get("id", "")),
			"last_selected_choice": last_selected_choice.duplicate(true),
			"selected_choice_sequence": selected_choice_sequence,
			"pending_skill_choices": pending_skill_choices,
		}


class FakeRuntimePerkCatalog:
	extends RefCounted


class FakeGameAudio:
	extends RefCounted

	var runtime_perk_choice_open_calls: int = 0
	var starpoint_collect_calls: int = 0

	func play_runtime_perk_choice_open() -> void:
		runtime_perk_choice_open_calls += 1

	func play_starpoint_collect() -> void:
		starpoint_collect_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_deferred_choice_flow()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_starpoint_choice_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_deferred_choice_flow() -> void:
	var handler := StageClearResultStarpointChoiceHandler.new()
	var scene := FakeScene.new()
	root.add_child(scene)
	var runtime_state := FakeRuntimePerkState.new()
	var runtime_catalog := FakeRuntimePerkCatalog.new()
	var game_audio := FakeGameAudio.new()

	_expect(handler.can_defer_choice(runtime_state, runtime_catalog), "handler should allow deferring when runtime choice opening is available")
	_expect(not handler.can_defer_choice(null, runtime_catalog), "handler should reject missing runtime perk state")
	_expect(not handler.is_runtime_perk_choice_active(runtime_state), "handler should read inactive runtime choice state")

	handler.schedule_deferred_choice(scene, 0, 0.10)
	var status: Dictionary = handler.get_status()
	_expect(float(status.get("pending_starpoint_choice_delay", 0.0)) > 0.0, "handler should expose the pending starpoint choice delay")
	_expect(int(status.get("pending_starpoint_choice_box_index", -1)) == 0, "handler should expose the pending starpoint box index")
	_expect(scene._starpoint_choice_gate_active, "handler should gate result scene input while waiting to open the choice")
	_expect(scene._starpoint_choice_gate_box_index == 0, "handler should store the gated box index")

	handler.update_pending_choice(0.04, scene, runtime_state, runtime_catalog, "viper", null, null, game_audio)
	_expect(runtime_state.open_calls == 0, "handler should wait for the deferred delay before opening")
	handler.update_pending_choice(0.08, scene, runtime_state, runtime_catalog, "viper", null, null, game_audio)
	_expect(runtime_state.open_calls == 1, "handler should open one deferred perk choice")
	_expect(runtime_state.choice_active, "handler should leave the runtime perk choice active after opening")
	_expect(str(runtime_state.last_selected_character_type) == "viper", "handler should pass the selected character to runtime perk state")
	_expect(str(runtime_state.last_choice_context.get("source", "")) == "result_box_starpoint_choice", "handler should tag result-box starpoint choice context")
	_expect(bool(runtime_state.last_choice_context.get("defer_instant_dimension_gate_until_spawn_intro_end", false)), "handler should defer instant dimension gate grants")
	_expect(bool(runtime_state.last_choice_context.get("defer_instant_full_gauge_until_spawn_intro_end", false)), "handler should defer instant full-gauge grants")
	_expect(game_audio.runtime_perk_choice_open_calls == 1, "handler should play the runtime perk choice open cue")
	_expect(game_audio.starpoint_collect_calls == 0, "handler should prefer the specific choice-open cue over the fallback")
	_expect(not scene._starpoint_choice_gate_active, "handler should clear the gate once the choice opens")
	status = handler.get_status()
	_expect(float(status.get("pending_starpoint_choice_delay", -1.0)) == 0.0, "handler should clear pending delay after opening")
	_expect(int(status.get("pending_starpoint_choice_box_index", 0)) == -1, "handler should clear pending box index after opening")

	handler.update_runtime_choice(0.016, scene, runtime_state, null, null)
	_expect(runtime_state.update_calls == 1, "handler should update the runtime perk state while the result scene is active")
	_expect(runtime_state.last_view_size.x > 0.0 and runtime_state.last_view_size.y > 0.0, "handler should pass a scene viewport size to runtime perk state")

	runtime_state.choice_active = false
	runtime_state.pending_skill_choices = 0
	runtime_state.selected_choice_sequence = 1
	handler.sync_box_perk_choice_rewards(scene, runtime_state)
	var reward: Dictionary = (scene._boxes[0] as Dictionary).get("reward", {}) as Dictionary
	var resolved: Array = reward.get("resolved_perk_rewards", []) as Array
	_expect(resolved.size() == 1, "handler should append one selected perk reward to the starpoint box")
	var perk_reward: Dictionary = resolved[0] if resolved[0] is Dictionary else {}
	_expect(str(perk_reward.get("type", "")) == "perk", "handler should append a perk reward")
	_expect(str(perk_reward.get("perk_id", "")) == "dash_module_control", "handler should preserve the selected perk id")
	_expect(str(perk_reward.get("source", "")) == "box_starpoint_choice", "handler should tag selected perks as box starpoint choices")
	_expect(int(reward.get("resolved_perk_count", 0)) == 1, "handler should update the resolved perk count")

	runtime_state.selected_choice_sequence = 1
	handler.sync_box_perk_choice_rewards(scene, runtime_state)
	reward = (scene._boxes[0] as Dictionary).get("reward", {}) as Dictionary
	resolved = reward.get("resolved_perk_rewards", []) as Array
	_expect(resolved.size() == 1, "handler should not duplicate the same selected perk sequence")
	scene.queue_free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_handler.gd")
	var choice_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_state.gd")
	var open_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_open_data.gd")
	var reward_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_perk_reward_data.gd")
	_expect(registry_source.find("StageClearResultStarpointChoiceHandler.new()") >= 0, "handler registry should delegate starpoint choice flow to its handler")
	_expect(screen_source.find("_pending_starpoint_choice_delay") < 0, "result screen should not own starpoint choice delay state")
	_expect(screen_source.find("set_starpoint_choice_gate_active") < 0, "result screen should not write starpoint gate scene fields directly")
	_expect(handler_source.find("StageClearResultStarpointChoiceState") >= 0, "starpoint choice handler should delegate choice-state storage")
	_expect(handler_source.find("consume_pending_choice_if_ready") >= 0, "starpoint choice handler should delegate pending delay state")
	_expect(handler_source.find("sync_box_perk_choice_rewards(scene, runtime_perk_state, _perk_catalog)") >= 0, "starpoint choice handler should delegate selected perk reward sync state")
	_expect(handler_source.find("StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active") < 0, "starpoint choice handler should not keep starpoint gate scene writes")
	_expect(handler_source.find("StageClearResultBoxSceneHandler.append_box_resolved_perk_reward") < 0, "starpoint choice handler should not append selected perk rewards directly")
	_expect(choice_state_source.find("StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active") >= 0, "starpoint choice state should own starpoint gate scene writes")
	_expect(choice_state_source.find("StageClearResultBoxSceneHandler.append_box_resolved_perk_reward") >= 0, "starpoint choice state should append selected perk rewards through the box scene handler")
	_expect(choice_state_source.find("func consume_pending_choice_if_ready") >= 0, "starpoint choice state should own pending delay countdown")
	_expect(choice_state_source.find("func record_open_result") >= 0, "starpoint choice state should own opened choice tracking")
	_expect(handler_source.find("StageClearResultStarpointChoiceOpenData.open_deferred_starpoint_choice") >= 0, "starpoint choice handler should delegate deferred runtime perk choice opening")
	_expect(handler_source.find("runtime_perk_state.open_next_choice") < 0, "starpoint choice handler should not call runtime perk choice opening directly")
	_expect(handler_source.find("play_runtime_perk_choice_open") < 0, "starpoint choice handler should not own choice-open audio fallback")
	_expect(choice_state_source.find("StageClearResultStarpointPerkRewardData.build_box_perk_choice_reward") >= 0, "starpoint choice state should delegate selected perk reward payload assembly")
	_expect(choice_state_source.find("StageClearResultStarpointPerkRewardData.get_runtime_perk_snapshot") >= 0, "starpoint choice state should delegate runtime perk snapshot copying")
	_expect(handler_source.find("func _build_box_perk_choice_reward") < 0, "starpoint choice handler should not keep selected perk reward payload assembly")
	_expect(handler_source.find("func _get_runtime_perk_snapshot") < 0, "starpoint choice handler should not keep runtime perk snapshot copying")
	_expect(handler_source.find("func _get_runtime_perk_choice_sequence") < 0, "starpoint choice handler should not keep runtime perk choice sequence extraction")
	_expect(reward_data_source.find("static func build_box_perk_choice_reward") >= 0, "starpoint perk reward data should own selected perk reward payload assembly")
	_expect(reward_data_source.find("static func get_runtime_perk_snapshot") >= 0, "starpoint perk reward data should own runtime perk snapshot copying")
	_expect(reward_data_source.find("static func get_runtime_perk_choice_sequence") >= 0, "starpoint perk reward data should own runtime perk choice sequence extraction")
	_expect(open_data_source.find("runtime_perk_state.open_next_choice") >= 0, "starpoint choice open data should own deferred runtime perk choice opening")
	_expect(open_data_source.find("static func build_choice_context") >= 0, "starpoint choice open data should own deferred choice context assembly")
	_expect(open_data_source.find("play_runtime_perk_choice_open") >= 0, "starpoint choice open data should own choice-open audio fallback")
	_expect(open_data_source.find("defer_instant_dimension_gate_until_spawn_intro_end") >= 0, "starpoint choice open data should own instant dimension gate deferral context")
	_expect(open_data_source.find("defer_instant_full_gauge_until_spawn_intro_end") >= 0, "starpoint choice open data should own instant full gauge deferral context")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
