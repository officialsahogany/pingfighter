extends SceneTree

const StageClearResultScreenStatusHandler := preload("res://scripts/core/stage_clear_result_screen_status_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeStatusHandler:
	extends RefCounted

	var status: Dictionary = {}

	func get_status() -> Dictionary:
		return status.duplicate(true)


class FakePlazaProgressHandler:
	extends RefCounted

	var summary: Dictionary = {}

	func get_cached_summary() -> Dictionary:
		return summary.duplicate(true)


class FakeScreen:
	extends RefCounted

	var active: bool = true
	var player_score: int = 0
	var boss_score: int = 0
	var current_stage: int = 1
	var _scene_node: Control
	var _spawn_pending: bool = false
	var _stage_start_snapshot: Dictionary = {}
	var _last_stage_reward_snapshot: Dictionary = {}
	var _reward_plan: Dictionary = {}
	var _plaza_progress_handler: Object
	var _reward_grant_handler: Object
	var _starpoint_choice_handler: Object
	var _plaza_scene_handler: Object

	func is_active() -> bool:
		return active

	func is_scene_ready() -> bool:
		return _scene_node != null and is_instance_valid(_scene_node)

	func get_reward_plan() -> Dictionary:
		return _reward_plan.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_status_schema_and_handler_merges()
	_verify_screen_adapter_builds_status()
	_verify_missing_handler_status_is_ignored()
	_verify_status_payloads_are_copied()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_screen_status_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_status_schema_and_handler_merges() -> void:
	var reward_handler := FakeStatusHandler.new()
	reward_handler.status = {
		"rewards_granted": true,
		"last_grant_summary": {"granted": 2},
	}
	var starpoint_handler := FakeStatusHandler.new()
	starpoint_handler.status = {
		"pending_starpoint_choice_delay": 0.4,
		"pending_starpoint_choice_box_index": 3,
	}
	var plaza_handler := FakeStatusHandler.new()
	plaza_handler.status = {
		"plaza_active": true,
		"plaza_prewarm_complete": true,
	}
	var status: Dictionary = StageClearResultScreenStatusHandler.new().build_status(
		true,
		5,
		1,
		6,
		{"reward_count": 3},
		"res://scenes/stage_clear_result.tscn",
		true,
		false,
		{"granted_ap": 1},
		{"runtime_gold": 12},
		{"stage_active_item_count": 2},
		reward_handler,
		starpoint_handler,
		plaza_handler
	)
	_expect(bool(status.get("active", false)), "screen status should expose active state")
	_expect(int(status.get("player_score", 0)) == 5, "screen status should expose player score")
	_expect(int(status.get("boss_score", 0)) == 1, "screen status should expose boss score")
	_expect(int(status.get("current_stage", 0)) == 6, "screen status should expose current stage")
	_expect(str(status.get("scene_path", "")) == "res://scenes/stage_clear_result.tscn", "screen status should expose scene path")
	_expect(bool(status.get("scene_ready", false)), "screen status should expose scene readiness")
	_expect(not bool(status.get("spawn_pending", true)), "screen status should expose pending spawn state")
	_expect(int((status.get("reward_plan", {}) as Dictionary).get("reward_count", 0)) == 3, "screen status should expose reward plan")
	_expect(int((status.get("last_plaza_progress_summary", {}) as Dictionary).get("granted_ap", 0)) == 1, "screen status should expose plaza progress summary")
	_expect(int((status.get("stage_start_snapshot", {}) as Dictionary).get("runtime_gold", 0)) == 12, "screen status should expose stage-start snapshot")
	_expect(int((status.get("stage_reward_snapshot", {}) as Dictionary).get("stage_active_item_count", 0)) == 2, "screen status should expose stage reward snapshot")
	_expect(bool(status.get("rewards_granted", false)), "screen status should merge reward grant status")
	_expect(int((status.get("last_grant_summary", {}) as Dictionary).get("granted", 0)) == 2, "screen status should merge reward grant summary")
	_expect(is_equal_approx(float(status.get("pending_starpoint_choice_delay", 0.0)), 0.4), "screen status should merge starpoint choice status")
	_expect(int(status.get("pending_starpoint_choice_box_index", -1)) == 3, "screen status should merge starpoint box index")
	_expect(bool(status.get("plaza_active", false)), "screen status should merge plaza activity")
	_expect(bool(status.get("plaza_prewarm_complete", false)), "screen status should merge plaza prewarm state")


func _verify_screen_adapter_builds_status() -> void:
	var scene := Control.new()
	root.add_child(scene)
	var screen := FakeScreen.new()
	screen.active = true
	screen.player_score = 7
	screen.boss_score = 2
	screen.current_stage = 5
	screen._scene_node = scene
	screen._spawn_pending = true
	screen._reward_plan = {"box_count": 4}
	screen._stage_start_snapshot = {"runtime_gold": 21}
	screen._last_stage_reward_snapshot = {"stage_active_item_count": 3}
	var plaza_progress := FakePlazaProgressHandler.new()
	plaza_progress.summary = {"granted_ap": 2}
	screen._plaza_progress_handler = plaza_progress
	var reward_handler := FakeStatusHandler.new()
	reward_handler.status = {"rewards_granted": true}
	screen._reward_grant_handler = reward_handler
	var starpoint_handler := FakeStatusHandler.new()
	starpoint_handler.status = {"pending_starpoint_choice_box_index": 1}
	screen._starpoint_choice_handler = starpoint_handler
	var plaza_handler := FakeStatusHandler.new()
	plaza_handler.status = {"plaza_active": false, "plaza_prewarm_complete": true}
	screen._plaza_scene_handler = plaza_handler

	var status: Dictionary = StageClearResultScreenStatusHandler.new().build_status_from_screen(
		screen,
		"res://scenes/stage_clear_result.tscn"
	)
	_expect(bool(status.get("active", false)), "screen status adapter should read active state from screen")
	_expect(int(status.get("player_score", 0)) == 7, "screen status adapter should read player score")
	_expect(int(status.get("boss_score", 0)) == 2, "screen status adapter should read boss score")
	_expect(int(status.get("current_stage", 0)) == 5, "screen status adapter should read current stage")
	_expect(bool(status.get("scene_ready", false)), "screen status adapter should read scene readiness")
	_expect(bool(status.get("spawn_pending", false)), "screen status adapter should read spawn pending")
	_expect(int((status.get("reward_plan", {}) as Dictionary).get("box_count", 0)) == 4, "screen status adapter should read reward plan")
	_expect(int((status.get("last_plaza_progress_summary", {}) as Dictionary).get("granted_ap", 0)) == 2, "screen status adapter should read plaza progress summary")
	_expect(int((status.get("stage_start_snapshot", {}) as Dictionary).get("runtime_gold", 0)) == 21, "screen status adapter should read stage-start snapshot")
	_expect(int((status.get("stage_reward_snapshot", {}) as Dictionary).get("stage_active_item_count", 0)) == 3, "screen status adapter should read stage reward snapshot")
	_expect(bool(status.get("rewards_granted", false)), "screen status adapter should merge reward handler status")
	_expect(int(status.get("pending_starpoint_choice_box_index", -1)) == 1, "screen status adapter should merge starpoint handler status")
	_expect(bool(status.get("plaza_prewarm_complete", false)), "screen status adapter should merge plaza handler status")
	scene.queue_free()


func _verify_missing_handler_status_is_ignored() -> void:
	var status: Dictionary = StageClearResultScreenStatusHandler.new().build_status(
		false,
		0,
		0,
		1,
		{},
		"res://scenes/stage_clear_result.tscn",
		false,
		true,
		{},
		{},
		{},
		null,
		RefCounted.new(),
		null
	)
	_expect(not bool(status.get("active", true)), "missing handler status should preserve base status")
	_expect(bool(status.get("spawn_pending", false)), "missing handler status should keep spawn pending")
	_expect(not status.has("rewards_granted"), "missing reward status should not synthesize reward fields")


func _verify_status_payloads_are_copied() -> void:
	var reward_plan := {"boxes": [{"id": "box"}]}
	var plaza_summary := {"nested": {"gold": 9}}
	var status: Dictionary = StageClearResultScreenStatusHandler.new().build_status(
		true,
		1,
		0,
		2,
		reward_plan,
		"res://scenes/stage_clear_result.tscn",
		false,
		false,
		plaza_summary,
		{},
		{},
		null,
		null,
		null
	)
	((status.get("reward_plan", {}) as Dictionary).get("boxes", []) as Array)[0]["id"] = "mutated"
	((status.get("last_plaza_progress_summary", {}) as Dictionary).get("nested", {}) as Dictionary)["gold"] = 0
	_expect(str(((reward_plan.get("boxes", []) as Array)[0] as Dictionary).get("id", "")) == "box", "screen status should deep-copy reward plan payloads")
	_expect(int((plaza_summary.get("nested", {}) as Dictionary).get("gold", 0)) == 9, "screen status should deep-copy plaza summary payloads")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen_status_handler.gd")
	var screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen_status_screen_data.gd")
	_expect(registry_source.find("StageClearResultScreenStatusHandler.new()") >= 0, "handler registry should delegate public status assembly")
	_expect(screen_source.find("\"rewards_granted\"") < 0, "result screen should not own reward status schema fields")
	_expect(screen_source.find("\"pending_starpoint_choice_delay\"") < 0, "result screen should not own starpoint status schema fields")
	_expect(screen_source.find("status.merge") < 0, "result screen should not merge handler status directly")
	_expect(screen_source.find("build_status(") < 0, "result screen should not pass status dependencies directly")
	_expect(screen_source.find("\"last_plaza_progress_summary\"") < 0, "result screen should not own plaza status schema fields")
	_expect(handler_source.find("func build_status") >= 0, "screen status handler should own status assembly")
	_expect(handler_source.find("func build_status_from_screen") >= 0, "screen status handler should expose the screen status adapter surface")
	_expect(handler_source.find("StageClearResultScreenStatusScreenData.build_status_from_screen") >= 0, "screen status handler should delegate screen-backed status adapters")
	_expect(handler_source.find("func _get_screen_object") < 0, "screen status handler should not own screen property readers")
	_expect(handler_source.find("func _get_screen_reward_plan") < 0, "screen status handler should not own screen reward-plan reads")
	_expect(handler_source.find("status.merge") >= 0, "screen status handler should own handler status merges")
	_expect(screen_data_source.find("static func build_status_from_screen") >= 0, "screen status screen data should own screen-backed status assembly")
	_expect(screen_data_source.find("status_handler.build_status") >= 0, "screen status screen data should route through the handler status schema")
	_expect(screen_data_source.find("static func _get_screen_reward_plan") >= 0, "screen status screen data should own screen reward-plan copying")
	_expect(screen_data_source.find("static func _get_cached_plaza_progress_summary") >= 0, "screen status screen data should own plaza progress summary reads")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the screen status handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
