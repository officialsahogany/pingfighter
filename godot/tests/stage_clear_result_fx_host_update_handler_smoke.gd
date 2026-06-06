extends SceneTree

const StageClearResultFxHostPool := preload("res://scripts/ui/stage_clear_result_fx_host_pool.gd")
const StageClearResultFxHostUpdateHandler := preload("res://scripts/ui/stage_clear_result_fx_host_update_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_update_handler_contract()
	_verify_update_handler_source()
	_verify_scene_delegates_fx_host_updates()

	if _failures.is_empty():
		print("stage_clear_result_fx_host_update_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_handler_contract() -> void:
	_expect(StageClearResultFxHostUpdateHandler != null, "FX host update handler preload should resolve")
	StageClearResultFxHostUpdateHandler.update_fx_hosts(null, null, [], 1.0, 0.0, "hidden", 0.0)

	var owner := Control.new()
	root.add_child(owner)
	var pool := StageClearResultFxHostPool.new()
	StageClearResultFxHostUpdateHandler.update_fx_hosts(
		pool,
		owner,
		[{"state": "opening", "base_pos": Vector2(220.0, 160.0), "open_progress": 0.25, "lid_open_id": 1}],
		1.0,
		0.25,
		"hidden",
		0.0
	)
	var status: Dictionary = pool.get_status()
	_expect(int(status.get("host_count", 0)) == 1, "FX host update handler should sync active result-box hosts")
	pool.tear_down()
	owner.free()


func _verify_update_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_fx_host_update_handler.gd")
	_expect(source.find("static func update_fx_hosts") >= 0, "FX host update handler should expose update_fx_hosts")
	_expect(source.find("prewarm_step") >= 0, "FX host update handler should call staged prewarm")
	_expect(source.find("sync(") >= 0, "FX host update handler should call pool sync")


func _verify_scene_delegates_fx_host_updates() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultFxHostUpdateHandler.update_fx_hosts") >= 0, "result scene should delegate per-frame FX host updates")
	_expect(source.find("_fx_host_pool.prewarm_step") < 0, "result scene should not call FX host prewarm directly during update")
	_expect(source.find("_fx_host_pool.sync") < 0, "result scene should not call FX host sync directly during update")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
