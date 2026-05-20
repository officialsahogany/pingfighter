extends SceneTree

const WarpGateFxHost := preload("res://scripts/characters/smasher_warp_gate_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_host_is_sync_driven_and_lazy_built()

	if _failures.is_empty():
		print("warp_gate_fx_host_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_host_is_sync_driven_and_lazy_built() -> void:
	var host: Node2D = WarpGateFxHost.new()
	get_root().add_child(host)

	_expect(host.get_child_count() == 0, "inactive warp gate host should not prebuild portal nodes")
	_expect(not host.is_processing(), "inactive warp gate host should not process outside the battle shell")

	host.sync_state([
		_build_portal_state(Vector2(120.0, 300.0), 180.0, -1, 1000),
		_build_portal_state(Vector2(640.0, 300.0), 180.0, 1, 1000),
	], true)

	_expect(host.visible, "active warp gate host should become visible after sync")
	_expect(not host.is_processing(), "active warp gate host should remain sync-driven, not _process-driven")
	_expect(host.get_child_count() == 8, "two warp gate portals should lazily build only two visual slots")

	host.sync_state([], false)
	_expect(not host.visible, "empty warp gate sync should hide the host")
	_expect(not host.is_processing(), "hidden warp gate host should remain outside process scanning")
	host.queue_free()


func _build_portal_state(center: Vector2, size: float, side: int, spawn_msec: int) -> Dictionary:
	return {
		"screen_center": center,
		"screen_size": size,
		"side": side,
		"kind": "active",
		"alpha": 1.0,
		"progress": 0.0,
		"spawn_msec": spawn_msec,
		"tint": Color(0.92, 0.45, 1.0, 0.88),
		"hot": Color(1.0, 0.84, 0.36),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
