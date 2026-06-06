extends SceneTree

const StageClearResultFxHostPool := preload("res://scripts/ui/stage_clear_result_fx_host_pool.gd")
const StageClearResultFxHostUpdateHandler := preload("res://scripts/ui/stage_clear_result_fx_host_update_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_pool_sync_and_lifecycle()
	_verify_scene_delegates_pool_lifecycle()

	if _failures.is_empty():
		print("stage_clear_result_fx_host_pool_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pool_sync_and_lifecycle() -> void:
	var owner := Control.new()
	root.add_child(owner)
	var pool := StageClearResultFxHostPool.new()
	var boxes := [
		{
			"state": "idle",
			"position": Vector2(100.0, 100.0),
		},
		{
			"state": "opening",
			"position": Vector2(220.0, 160.0),
			"open_progress": 0.4,
			"reward_emerge": 0.0,
			"kind": "normal",
			"lid_open_id": 1,
		},
		{
			"state": "opened",
			"position": Vector2(340.0, 170.0),
			"open_progress": 1.0,
			"reward_emerge": 0.8,
			"kind": "advanced",
			"lid_open_id": 2,
		},
	]

	pool.sync(owner, boxes, 1.0, 0.25, "hidden", 0.0, 1.0, 5.0, 1.4)
	var status: Dictionary = pool.get_status()
	_expect(int(status.get("host_count", 0)) == 2, "pool sync should build hosts only for active result boxes")
	var idle_host: Node = owner.get_node_or_null("ResultBoxOpenFxHost_0")
	var opening_host: Node = owner.get_node_or_null("ResultBoxOpenFxHost_1")
	var opened_host: Node = owner.get_node_or_null("ResultBoxOpenFxHost_2")
	_expect(idle_host == null, "idle boxes should not allocate FX hosts during sync")
	_expect(opening_host != null and opening_host.visible, "opening boxes should activate an FX host")
	_expect(opened_host != null and opened_host.visible, "opened boxes should activate an FX host")

	pool.deactivate_all()
	_expect(not opening_host.visible and not opened_host.visible, "deactivate_all should hide active hosts")
	pool.reset_prewarm()
	pool.prewarm_step(owner, boxes)
	status = pool.get_status()
	_expect(int(status.get("prewarm_next_index", 0)) == 1, "prewarm step should advance its cursor")
	_expect(owner.get_node_or_null("ResultBoxOpenFxHost_0") != null, "prewarm should allocate the next box host")
	pool.sync(owner, [], 1.0, 0.0, "hidden", 0.0, 1.0, 5.0, 1.4)
	_expect(not (owner.get_node("ResultBoxOpenFxHost_0") as Node2D).visible, "empty sync should deactivate prewarmed hosts")
	pool.tear_down()
	status = pool.get_status()
	_expect(int(status.get("host_count", -1)) == 0, "tear_down should clear host tracking")
	owner.free()


func _verify_scene_delegates_pool_lifecycle() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultFxHostPool.new()") >= 0,
		"stage-clear result scene should own a result-box FX host pool"
	)
	_expect(
		source.find("StageClearResultFxHostUpdateHandler.update_fx_hosts") >= 0
			and StageClearResultFxHostUpdateHandler != null,
		"stage-clear result scene should delegate per-frame FX host update sequencing"
	)
	for removed_fragment in [
		"var _fx_hosts",
		"func _sync_fx_hosts",
		"func _prewarm_fx_hosts_step",
		"func _ensure_fx_host",
		"ResultBoxOpenFxHost.new()",
		"_fx_host_pool.prewarm_step",
		"_fx_host_pool.sync",
	]:
		_expect(
			source.find(removed_fragment) < 0,
			"stage-clear result scene should delegate FX host lifecycle fragment: %s" % removed_fragment
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
