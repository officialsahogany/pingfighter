extends SceneTree

const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_no_cache_churn()
	_verify_geometry_params()
	_verify_color_mutation_isolation()

	if _failures.is_empty():
		print("premium_panel_frame_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_no_cache_churn() -> void:
	var before: Dictionary = PremiumPanelFrame.cache_instance_ids_for_tests()
	for i in range(50):
		var main_box: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_MAIN, Color(0.02, 0.04, 0.08, 0.90), Color(0.38, 0.72, 1.0, 0.90), 3.0)
		var section_box: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_SECTION, Color(0.04, 0.07, 0.12, 0.84), Color(0.38, 0.72, 1.0, 0.52), 2.0)
		var slot_box: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_SLOT, Color(0.05, 0.08, 0.12, 0.76), Color(0.55, 0.85, 1.0, 0.58), 1.4)
		var cell_box: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_CELL, Color(0.05, 0.08, 0.12, 0.72), Color(0.55, 0.85, 1.0, 0.48), 1.0)
		_expect(main_box.get_instance_id() == int(before.get("main", -1)), "main stylebox should be reused directly")
		_expect(section_box.get_instance_id() == int(before.get("section", -1)), "section stylebox should be reused directly")
		_expect(slot_box.get_instance_id() == int(before.get("slot", -1)), "slot stylebox should be reused directly")
		_expect(cell_box.get_instance_id() == int(before.get("cell", -1)), "cell stylebox should be reused directly")
	var after: Dictionary = PremiumPanelFrame.cache_instance_ids_for_tests()
	_expect(before == after, "premium panel frame should reuse cached StyleBoxFlat instances")

	var equipment_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_equipment_drawer.gd")
	_expect(equipment_source.find("PremiumPanelFrame.draw_corner_brackets") >= 0, "equipment slot hover brackets should use the shared helper")


func _verify_geometry_params() -> void:
	var geometry: Dictionary = PremiumPanelFrame.geometry_snapshot_for_tests()
	var main: Dictionary = geometry.get("main", {})
	var section: Dictionary = geometry.get("section", {})
	var slot: Dictionary = geometry.get("slot", {})
	var cell: Dictionary = geometry.get("cell", {})
	var halo: Dictionary = geometry.get("halo", {})
	_expect(int(main.get("radius", 0)) == 12, "main panel should keep the 12px round radius")
	_expect(int(section.get("radius", 0)) == 8, "section panel should keep the 8px round radius")
	_expect(int(slot.get("radius", 0)) == 6, "slot panel should keep the 6px round radius")
	_expect(int(cell.get("radius", 0)) == 4, "cell panel should keep the 4px round radius")
	_expect(bool(main.get("anti_aliasing", false)), "main panel should enable anti-aliasing")
	_expect(bool(section.get("anti_aliasing", false)), "section panel should enable anti-aliasing")
	_expect(int(main.get("shadow_size", 0)) > 0, "main panel should have a soft shadow")
	_expect(int(section.get("shadow_size", 0)) > 0, "section panel should have a soft shadow")
	_expect(int(cell.get("shadow_size", -1)) == 0, "dense grid cells should not carry shadows")
	_expect(not bool(halo.get("draw_center", true)), "main halo should draw as a border-only pass")


func _verify_color_mutation_isolation() -> void:
	var fill_a := Color(0.01, 0.02, 0.03, 0.40)
	var border_a := Color(0.20, 0.40, 0.80, 0.50)
	var fill_b := Color(0.08, 0.10, 0.14, 0.88)
	var border_b := Color(0.55, 0.88, 1.00, 0.94)
	var box_a: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_SLOT, fill_a, border_a, 1.4)
	var instance_id: int = box_a.get_instance_id()
	var radius: int = box_a.corner_radius_top_left
	var box_b: StyleBoxFlat = PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_SLOT, fill_b, border_b, 2.0)
	_expect(box_b.get_instance_id() == instance_id, "slot stylebox should be mutated in place")
	_expect(box_b.bg_color.is_equal_approx(fill_b), "slot fill color should update on the cached stylebox")
	_expect(box_b.border_color.is_equal_approx(border_b), "slot border color should update on the cached stylebox")
	_expect(box_b.corner_radius_top_left == radius, "slot color mutation should not change geometry")
	_expect(box_b.border_width_left == 2, "slot border width should update from the draw call")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
