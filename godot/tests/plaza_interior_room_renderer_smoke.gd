extends SceneTree

const PlazaInteriorRoomRenderer := preload("res://scripts/plaza/plaza_interior_room_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_expect(PlazaInteriorRoomRenderer.get_cover_source_rect(Vector2(200.0, 100.0), Vector2(100.0, 100.0)) == Rect2(Vector2(50.0, 0.0), Vector2(100.0, 100.0)), "wide backdrop should crop equally from both horizontal sides")
	_expect(PlazaInteriorRoomRenderer.get_cover_source_rect(Vector2(100.0, 200.0), Vector2(100.0, 100.0)) == Rect2(Vector2(0.0, 50.0), Vector2(100.0, 100.0)), "tall backdrop should crop equally from top and bottom")
	_expect(PlazaInteriorRoomRenderer.get_cover_source_rect(Vector2(160.0, 90.0), Vector2(160.0, 90.0)) == Rect2(Vector2.ZERO, Vector2(160.0, 90.0)), "matching aspect should retain the complete source")
	_expect(PlazaInteriorRoomRenderer.get_cover_source_rect(Vector2.ZERO, Vector2(100.0, 100.0)).is_equal_approx(Rect2()), "invalid texture size should reject cover projection")
	_expect(PlazaInteriorRoomRenderer.get_neon_label("bank") == "BANK", "bank procedural room should retain the BANK sign")
	_expect(PlazaInteriorRoomRenderer.get_neon_label("shop") == "", "top-view shop should not receive a procedural neon label")
	if _failures.is_empty():
		print("plaza_interior_room_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
