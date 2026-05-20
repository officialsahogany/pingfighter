extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPaddleSync := preload("res://scripts/items/active_item_paddle_sync.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0


class FakeWarpGate:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeMythicRuntime:
	extends RefCounted

	var paddle_scale := 1.0

	func get_player_paddle_scale() -> float:
		return paddle_scale


func _init() -> void:
	_verify_scale_helpers()
	_verify_owner_sync_preserves_bottom_alignment()
	_verify_owner_sync_uses_runtime_base_size()
	_verify_warp_gate_bounds()
	_verify_controller_delegates_to_paddle_sync()

	if _failures.is_empty():
		print("active_item_paddle_sync_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scale_helpers() -> void:
	var sync: Object = ActiveItemPaddleSync.new()
	var scale: float = sync.get_player_paddle_scale(1.5, 0.5)
	_expect(is_equal_approx(scale, 0.75), "active item paddle scale should multiply long boost and strange vial")
	_expect(is_equal_approx(sync.get_player_paddle_width(scale), 116.25), "paddle width should use active item scale")
	_expect(is_equal_approx(sync.get_player_paddle_height(scale), 37.5), "paddle height should use active item scale")


func _verify_owner_sync_preserves_bottom_alignment() -> void:
	var sync: Object = ActiveItemPaddleSync.new()
	var owner := FakeOwner.new()
	var mythic := FakeMythicRuntime.new()
	owner.runtime_paddle_scale = 1.2
	mythic.paddle_scale = 1.1

	sync.sync_owner_state(owner, 1.5, null, mythic)

	_expect(is_equal_approx(owner.player_paddle_width, 306.9), "owner width should include runtime, mythic, and active item scales")
	_expect(is_equal_approx(owner.player_paddle_height, 99.0), "owner height should include runtime, mythic, and active item scales")
	_expect(is_equal_approx(owner.player_paddle_scale, 1.98), "owner paddle scale should include all scale sources")
	_expect(is_equal_approx(owner.player_pos.y + owner.player_paddle_height, 750.0), "bottom-aligned paddle should stay on the floor after resize")


func _verify_owner_sync_uses_runtime_base_size() -> void:
	var sync: Object = ActiveItemPaddleSync.new()
	var owner := FakeOwner.new()
	owner.player_paddle_width = 296.0
	owner.player_paddle_height = 147.0
	owner.runtime_paddle_base_width = 296.0
	owner.runtime_paddle_base_height = 147.0
	owner.player_pos = Vector2(120.0, 603.0)

	sync.sync_owner_state(owner, 1.0)

	_expect(is_equal_approx(owner.player_paddle_width, 296.0), "runtime base width should preserve Optimus paddle width")
	_expect(is_equal_approx(owner.player_paddle_height, 147.0), "runtime base height should preserve Optimus paddle height")
	_expect(is_equal_approx(owner.player_paddle_scale, 296.0 / 155.0), "player scale should reflect runtime base width")
	_expect(is_equal_approx(owner.player_pos.y + owner.player_paddle_height, 750.0), "runtime base sync should keep Optimus paddle on the floor")


func _verify_warp_gate_bounds() -> void:
	var sync: Object = ActiveItemPaddleSync.new()
	var warp_gate := FakeWarpGate.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(720.0, 700.0)

	sync.sync_owner_state(owner, 1.5)
	_expect(owner.player_pos.x <= 760.0 - owner.player_paddle_width, "inactive sync should clamp resized paddle inside playfield")

	warp_gate.active = true
	owner = FakeOwner.new()
	owner.player_pos = Vector2(-42.0, 700.0)
	sync.sync_owner_state(owner, 1.5, warp_gate)
	_expect(owner.player_pos.x < 0.0, "active warp gate should preserve left wall riding during active-item resize")

	owner = FakeOwner.new()
	owner.player_pos = Vector2(620.0, 700.0)
	sync.sync_owner_state(owner, 1.5, warp_gate)
	_expect(owner.player_pos.x > 760.0 - owner.player_paddle_width, "active warp gate should preserve right wall riding during active-item resize")


func _verify_controller_delegates_to_paddle_sync() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.long_boost_scale = 1.5
	controller.strange_vial_scale = 0.5
	_expect(is_equal_approx(controller.get_player_paddle_scale(), 0.75), "effect controller scale getter should delegate to paddle sync")
	_expect(is_equal_approx(controller.get_player_paddle_width(), 116.25), "effect controller width getter should delegate to paddle sync")
	_expect(is_equal_approx(controller.get_player_paddle_height(), 37.5), "effect controller height getter should delegate to paddle sync")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
