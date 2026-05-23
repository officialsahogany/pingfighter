extends SceneTree

const ActiveItemEffectUpdateDriver := preload("res://scripts/items/active_item_effect_update_driver.gd")

var _failures: Array[String] = []


class FakeTarget:
	extends RefCounted

	var long_boost_active := false
	var long_boost_timer_frames := 0.0
	var long_boost_scale := 1.0
	var strange_vial_active := false
	var strange_vial_timer_frames := 0.0
	var strange_vial_scale := 1.0


class FakePaddleSync:
	extends RefCounted

	var sync_count := 0
	var synced_scales: Array[float] = []

	func get_player_paddle_scale(long_boost_scale: float, strange_vial_scale: float) -> float:
		return long_boost_scale * strange_vial_scale

	func sync_owner_state(
		_owner: Object,
		active_item_scale: float,
		_warp_gate_state: Object = null,
		_mythic_item_runtime: Object = null
	) -> void:
		sync_count += 1
		synced_scales.append(active_item_scale)


func _init() -> void:
	_verify_idle_paddle_sync_gate()

	if _failures.is_empty():
		print("active_item_paddle_sync_idle_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_idle_paddle_sync_gate() -> void:
	var driver := ActiveItemEffectUpdateDriver.new()
	var paddle_sync := FakePaddleSync.new()
	var target := FakeTarget.new()
	var owner := RefCounted.new()
	driver.configure({"paddle_sync": paddle_sync})

	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 1, "idle paddle sync should run once to establish owner state")
	_expect(_last_synced_scale(paddle_sync) == 1.0, "initial active-item scale should be neutral")

	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 1, "idle paddle sync should skip repeated same-frame neutral work")

	target.long_boost_scale = 1.35
	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 2, "non-neutral long-boost scale should force sync")
	_expect(_last_synced_scale(paddle_sync) > 1.3, "long-boost scale should be forwarded to owner sync")

	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 3, "active paddle scale work should keep syncing every tick")

	target.long_boost_scale = 1.0
	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 4, "returning to neutral scale should sync the restore")
	_expect(_last_synced_scale(paddle_sync) == 1.0, "neutral restore scale should be forwarded")

	driver._sync_paddle_owner_state(target, owner, null, null)
	_expect(paddle_sync.sync_count == 4, "restored idle paddle sync should gate repeated work again")


func _last_synced_scale(paddle_sync: FakePaddleSync) -> float:
	if paddle_sync.synced_scales.is_empty():
		return -1.0
	return paddle_sync.synced_scales[paddle_sync.synced_scales.size() - 1]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
