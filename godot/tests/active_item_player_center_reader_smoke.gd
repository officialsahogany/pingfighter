extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPlayerCenterReader := preload("res://scripts/items/active_item_player_center_reader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_direct_player_center_reads()
	_verify_controller_delegates_player_center_reads()

	if _failures.is_empty():
		print("active_item_player_center_reader_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_player_center_reads() -> void:
	var reader: Object = ActiveItemPlayerCenterReader.new()
	var owner := FakeOwner.new()

	_expect(reader.get_player_center(owner) == Vector2(160.0, 620.0), "reader should build player center from owner pos and paddle size")
	_expect(reader.get_player_anchor(owner, 0.45) == Vector2(160.0, 618.0), "reader should support non-center player anchors")

	owner.player_paddle_width = 0.0
	owner.player_paddle_height = -10.0
	_expect(reader.get_player_paddle_size(owner) == Vector2(1.0, 1.0), "reader should clamp invalid paddle sizes to the legacy minimum")

	_expect(reader.get_player_center(null) == Vector2(380.0, 725.0), "reader should preserve default bottom-center fallback")


func _verify_controller_delegates_player_center_reads() -> void:
	var magnet_controller: Object = ActiveItemEffectController.new()
	var magnet_owner := FakeOwner.new()

	_expect(magnet_controller.activate_magnet_field(magnet_owner, null), "controller should activate magnet field for center read")
	_expect(magnet_controller.magnet_field_player_center == Vector2(160.0, 620.0), "controller magnet field center should delegate to reader")
	magnet_owner.player_pos = Vector2(200.0, 610.0)
	magnet_controller.update(magnet_owner, 1.0 / 60.0)
	_expect(magnet_controller.magnet_field_player_center == Vector2(260.0, 630.0), "controller magnet field update should refresh center through reader")

	var vitamin_controller: Object = ActiveItemEffectController.new()
	var vitamin_owner := FakeOwner.new()
	_expect(vitamin_controller.activate_vitamin_pill(vitamin_owner, null), "controller should activate vitamin pill for center read")
	_expect(vitamin_controller.vitamin_pill_player_center == Vector2(160.0, 620.0), "controller vitamin pill center should delegate to reader")
	vitamin_owner.player_pos = Vector2(150.0, 640.0)
	vitamin_controller.update(vitamin_owner, 1.0 / 60.0)
	_expect(vitamin_controller.vitamin_pill_player_center == Vector2(210.0, 660.0), "controller vitamin pill update should refresh center through reader")

	var strange_controller: Object = ActiveItemEffectController.new()
	var strange_owner := FakeOwner.new()
	seed(71)
	_expect(strange_controller.activate_strange_vial(strange_owner, null), "controller should activate strange vial for center read")
	_expect(strange_controller.strange_vial_player_center == Vector2(160.0, 620.0), "controller strange vial center should delegate to reader")
	strange_owner.player_pos = Vector2(180.0, 590.0)
	strange_owner.player_paddle_width = 120.0
	strange_owner.player_paddle_height = 40.0
	strange_controller.update(strange_owner, 1.0 / 60.0)
	_expect(strange_controller.strange_vial_player_center == Vector2(240.0, 610.0), "controller strange vial update should refresh center through reader")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
