extends SceneTree

const PlazaInteriorChromeProjection := preload("res://scripts/plaza/plaza_interior_chrome_projection.gd")
const PlazaInteriorLayout := preload("res://scripts/plaza/plaza_interior_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_title_snapshot()
	_verify_npc_snapshots()
	_verify_speech_snapshot()
	_verify_object_panel_snapshot()
	if _failures.is_empty():
		print("plaza_interior_chrome_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_title_snapshot() -> void:
	var snapshot := PlazaInteriorChromeProjection.build_title_snapshot("상점", "좋은 물건", 321, 0.5)
	_expect(snapshot.get("title_rect", Rect2()) == Rect2(PlazaInteriorLayout.TITLE_RECT.position * 0.5, PlazaInteriorLayout.TITLE_RECT.size * 0.5), "title rect should scale from the canonical layout")
	_expect(str(snapshot.get("title", "")) == "VR 상점", "title projection should preserve the VR prefix")
	_expect(str(snapshot.get("gold_text", "")) == "321G", "title projection should format plaza gold")
	_expect(PlazaInteriorChromeProjection.build_title_snapshot("", "", 0, 0.0).is_empty(), "zero scale should reject title projection")


func _verify_npc_snapshots() -> void:
	var textured := PlazaInteriorChromeProjection.build_npc_snapshot("미카", "", Color(0.2, 0.4, 0.8), true, Vector2(100.0, 200.0), 1.0)
	_expect(textured.get("texture_rect", Rect2()).has_area(), "valid NPC texture size should project a fitted rect")
	_expect(not bool(textured.get("show_placeholder", true)), "present NPC texture should suppress the placeholder")
	_expect(str(textured.get("message", "")) == PlazaInteriorChromeProjection.DEFAULT_NPC_MESSAGE, "empty NPC message should use the canonical fallback")
	var placeholder := PlazaInteriorChromeProjection.build_npc_snapshot("미카", "어서 와", Color.WHITE, false, Vector2.ZERO, 1.0)
	_expect(bool(placeholder.get("show_placeholder", false)), "missing NPC texture should project the placeholder")
	_expect(not _get_dict(placeholder.get("placeholder", {})).is_empty(), "placeholder projection should include concrete geometry")
	var topview := PlazaInteriorChromeProjection.build_topview_npc_snapshot(true, Vector2(100.0, 200.0), 1.0)
	_expect(topview.get("draw_rect", Rect2()).has_area(), "top-view NPC should project a fitted draw rect")
	_expect(PlazaInteriorChromeProjection.build_topview_npc_snapshot(false, Vector2.ZERO, 1.0).is_empty(), "missing top-view NPC texture should not project a draw")


func _verify_speech_snapshot() -> void:
	var snapshot := PlazaInteriorChromeProjection.build_speech_bubble_snapshot("첫 줄|둘째 줄|무시", 1.0)
	var lines: Array = snapshot.get("lines", [])
	_expect(lines.size() == 2 and str(lines[0]) == "첫 줄" and str(lines[1]) == "둘째 줄", "speech projection should retain at most two ordered lines")
	var tail: PackedVector2Array = snapshot.get("tail", PackedVector2Array())
	_expect(tail.size() == 3, "speech tail should retain three vertices")
	_expect(not Geometry2D.triangulate_polygon(tail).is_empty(), "speech tail should remain triangulable")


func _verify_object_panel_snapshot() -> void:
	var snapshot := PlazaInteriorChromeProjection.build_object_panel_snapshot({"label": "합성"}, Color(0.4, 0.6, 1.0), 7, "준비 완료", 1.0)
	_expect(str(snapshot.get("title", "")) == "합성", "object panel should project the selected label")
	_expect(str(snapshot.get("ap_text", "")) == "AP 7", "object panel should project current AP")
	_expect(_get_dict(snapshot.get("confirm_button", {})).get("rect", Rect2()) == PlazaInteriorLayout.PANEL_CONFIRM_RECT, "object panel should retain canonical confirm hit geometry")
	_expect(PlazaInteriorChromeProjection.build_object_panel_snapshot({}, Color.WHITE, 0, "", 1.0).is_empty(), "empty object spec should reject panel projection")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
