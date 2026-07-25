extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetRingCoreProjection := preload("res://scripts/hud/character_info_overlay_lingpet_ring_core_projection.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_row_projection_and_clamps()
	_verify_hover_and_tooltip_projection()
	_verify_vertical_pip_projection()
	_verify_presenter_boundary_contract()
	if _failures.is_empty():
		print("character_info_lingpet_ring_core_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_row_projection_and_clamps() -> void:
	var row_rect := Rect2(40.0, 200.0, 240.0, 64.0)
	var projection := CharacterInfoOverlayLingpetRingCoreProjection.build_row({
		"ring_core_tier": 999,
		"affinity_chip_count": 999,
	}, row_rect)
	_expect(int(projection.get("tier", 0)) == LingpetRingCoreRules.MAX_RING_CORE_TIER, "row projection should clamp Ring Core tier")
	_expect(int(projection.get("chip_count", 0)) == LingpetAffinityState.MAX_ENHANCEMENT_CHIPS, "row projection should clamp affinity chips")
	var slot_rect: Rect2 = projection.get("ring_core_rect", Rect2())
	var pips_rect: Rect2 = projection.get("chip_pips_rect", Rect2())
	var pips_hover_rect: Rect2 = projection.get("chip_pips_hover_rect", Rect2())
	_expect(slot_rect.size == Vector2(58.0, 58.0), "64px row should clamp the Ring Core slot to 58px")
	_expect(slot_rect.position.y > row_rect.position.y and slot_rect.end.y < row_rect.end.y, "Ring Core slot should stay vertically centered")
	_expect(pips_rect.position.x > slot_rect.end.x, "chip pips should remain right of the Ring Core slot")
	_expect(pips_hover_rect.position.x < pips_rect.position.x and pips_hover_rect.size.x > pips_rect.size.x, "chip hover target should pad the narrow pip column")
	_expect(str(projection.get("tier_text", "")) == "T%d" % LingpetRingCoreRules.MAX_RING_CORE_TIER, "row projection should expose the clamped tier label")


func _verify_hover_and_tooltip_projection() -> void:
	var row_rect := Rect2(40.0, 200.0, 240.0, 64.0)
	var pips_rect := Rect2(100.0, 200.0, 14.0, 64.0)
	_expect(CharacterInfoOverlayLingpetRingCoreProjection.hover_target(row_rect, pips_rect, Vector2(105.0, 225.0)) == &"chip", "pip column should win hover arbitration")
	_expect(CharacterInfoOverlayLingpetRingCoreProjection.hover_target(row_rect, pips_rect, Vector2(180.0, 225.0)) == &"ring_core", "remaining row should resolve Ring Core hover")
	_expect(CharacterInfoOverlayLingpetRingCoreProjection.hover_target(row_rect, pips_rect, Vector2(400.0, 225.0)) == &"", "outside point should resolve no hover")
	var chip_tooltip := CharacterInfoOverlayLingpetRingCoreProjection.tooltip_spec(3, 4, &"chip")
	_expect(str(chip_tooltip.get("title", "")).find("4 / %d" % LingpetAffinityState.MAX_ENHANCEMENT_CHIPS) >= 0, "chip tooltip should expose current/max count")
	_expect(str(chip_tooltip.get("body", "")).find("80%") >= 0, "four chips should expose the existing +80% affinity copy")
	var core_tooltip := CharacterInfoOverlayLingpetRingCoreProjection.tooltip_spec(3, 4, &"ring_core")
	_expect(str(core_tooltip.get("subtitle", "")) == "T3", "Ring Core tooltip should expose tier")
	_expect(str(core_tooltip.get("body", "")).find("Lv.%d" % LingpetRingCoreRules.get_ring_core_cap_for_tier(3)) >= 0, "Ring Core tooltip should expose tier affinity cap")


func _verify_vertical_pip_projection() -> void:
	var rect := Rect2(100.0, 200.0, 8.0, 64.0)
	var pips := CharacterInfoOverlayLingpetRingCoreProjection.build_vertical_pips(rect, 4)
	_expect(pips.size() == LingpetAffinityState.MAX_ENHANCEMENT_CHIPS, "vertical projection should create one pip per enhancement slot")
	var filled_count := 0
	var previous_rect := Rect2()
	for index in range(pips.size()):
		var pip: Dictionary = pips[index]
		var pip_rect: Rect2 = pip.get("rect", Rect2())
		if bool(pip.get("filled", false)):
			filled_count += 1
		if index > 0:
			_expect(pip_rect.position.y > previous_rect.position.y, "vertical pips should remain top-to-bottom ordered")
		previous_rect = pip_rect
	_expect(filled_count == mini(4, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS), "vertical projection should mark the requested leading pips filled")


func _verify_presenter_boundary_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var projection_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_ring_core_projection.gd")
	_expect(_function_body(presenter_source, "static func _draw_lingpet_ring_core_row(").find("CharacterInfoOverlayLingpetRingCoreProjection.build_row") >= 0, "Ring Core row drawer should consume the focused projection")
	_expect(_function_body(presenter_source, "static func _ring_core_row_hover_target(").find("CharacterInfoOverlayLingpetRingCoreProjection.hover_target") >= 0, "hover facade should delegate to the projection")
	_expect(_function_body(presenter_source, "static func _ring_core_icon_rect(").find("CharacterInfoOverlayLingpetRingCoreProjection.icon_rect") >= 0, "icon geometry facade should delegate to the projection")
	_expect(_function_body(presenter_source, "static func _draw_vertical_affinity_chip_pips(").find("CharacterInfoOverlayLingpetRingCoreProjection.build_vertical_pips") >= 0, "pip drawer should consume projected pip geometry")
	_expect(projection_source.find("CanvasItem") < 0 and projection_source.find("FileAccess") < 0, "Ring Core projection should remain draw- and I/O-free")
	_expect(CharacterInfoOverlayLingpetPresenter._ring_core_icon_rect(Rect2(40.0, 200.0, 50.0, 50.0)) == CharacterInfoOverlayLingpetRingCoreProjection.icon_rect(Rect2(40.0, 200.0, 50.0, 50.0)), "presenter icon facade should preserve projection geometry")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
