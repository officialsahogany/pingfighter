extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")

const CONTENT_RECT := Rect2(Vector2(24.0, 22.0), Vector2(300.0, 360.0))

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contract()
	_verify_runtime_snapshot_merge()
	_verify_satiety_states()
	_verify_strip_layout()
	_verify_bar_hover_zones()
	_verify_unlock_gate_survives_expanded_band()
	call_deferred("_finish")


func _verify_source_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	_expect(presenter_source.find("const AFFINITY_BAND_HEIGHT := 50.0") >= 0, "TAB lingpet affinity band should be expanded for the satiety strip")
	_expect(presenter_source.find("max(24.0, affinity_band_h - 10.0)") >= 0, "TAB lingpet affinity rect should keep the 42px unlock-choice gate after the expanded band")
	_expect(presenter_source.find("satiety_pct") >= 0, "TAB satiety strip should consume the active runtime satiety snapshot")
	_expect(presenter_source.find("companion_exhausted") >= 0, "TAB satiety strip should distinguish exhausted 0 from no-pet 0")
	_expect(presenter_source.find("satiety_exhaustion_ratio") >= 0, "TAB satiety strip should keep the exhaustion telegraph ratio in the render contract")
	_expect(presenter_source.find("lingpet_satiety_pct") < 0, "TAB satiety strip should not read the owner-only lingpet_satiety_pct key")
	_expect(frame_source.find("merge_runtime_satiety_snapshot") >= 0, "TAB frame presenter should merge the existing lingpet runtime snapshot into the panel snapshot")
	_expect(frame_source.find("lingpet_satiety_pct") < 0, "TAB frame presenter should not read the owner-only lingpet_satiety_pct key")
	# Bar hover tooltips: the caller must thread mouse/hover into draw_affinity_status
	# and the drawer must publish both bar tooltip bodies through _fill_hover_data.
	_expect(presenter_source.find("draw_affinity_status(canvas, font, affinity_rect, snapshot, stat_buff_color, empty_text_color, accent_blue, ui_text_scale, mouse_pos, hover_data)") >= 0, "TAB affinity/satiety draw should receive mouse_pos + hover_data for bar tooltips")
	_expect(presenter_source.find("이번 판 동안 링펫과 쌓은 교감 수치입니다") >= 0, "교감 bar hover should publish an affinity tooltip body")
	_expect(presenter_source.find("링펫의 포만도입니다. 시간이 지나면 서서히 줄고") >= 0, "포만도 bar hover should publish a satiety tooltip body")


func _verify_runtime_snapshot_merge() -> void:
	var panel_snapshot := {
		"state": "companion",
		"pet_id": "maribo",
	}
	var runtime_snapshot := {
		"satiety_pct": 41,
		"companion_exhausted": false,
		"satiety_exhaustion_ratio": 0.25,
	}
	CharacterInfoOverlayLingpetPresenter.merge_runtime_satiety_snapshot(panel_snapshot, runtime_snapshot)
	_expect(int(panel_snapshot.get("satiety_pct", -1)) == 41, "panel snapshot should receive active satiety_pct from the existing runtime snapshot")
	_expect(not bool(panel_snapshot.get("companion_exhausted", true)), "panel snapshot should receive active companion_exhausted from the existing runtime snapshot")
	_expect(is_equal_approx(float(panel_snapshot.get("satiety_exhaustion_ratio", -1.0)), 0.25), "panel snapshot should receive satiety_exhaustion_ratio from the existing runtime snapshot")


func _verify_satiety_states() -> void:
	var normal := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"satiety_pct": 73,
		"companion_exhausted": false,
		"satiety_exhaustion_ratio": 0.0,
	})
	_expect(bool(normal.get("visible", false)), "normal companion should show the TAB satiety strip")
	_expect(str(normal.get("color_key", "")) == "normal", "satiety above 50 should use the normal color key")
	_expect(str(normal.get("value", "")) == "73%", "normal satiety strip should show the quantized percent")

	var warning := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"satiety_pct": 50,
		"companion_exhausted": false,
	})
	_expect(str(warning.get("color_key", "")) == "warning", "satiety at 50 should enter the yellow warning color key")

	var critical := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"satiety_pct": 20,
		"companion_exhausted": false,
	})
	_expect(str(critical.get("color_key", "")) == "critical", "satiety at 20 should enter the red critical color key")

	var exhausted := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"satiety_pct": 0,
		"companion_exhausted": true,
		"satiety_exhaustion_ratio": 1.0,
	})
	_expect(bool(exhausted.get("visible", false)), "exhausted companion should still show the TAB satiety strip")
	_expect(str(exhausted.get("color_key", "")) == "critical", "exhausted companion should use the red critical color key")
	_expect(str(exhausted.get("value", "")).find("탈진") >= 0, "exhausted companion should render the 탈진 label")

	var no_pet := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "none",
		"satiety_pct": 0,
		"companion_exhausted": true,
	})
	_expect(not bool(no_pet.get("visible", true)), "no-pet state should hide the strip even though satiety_pct is also 0")

	var empty_companion := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "",
		"satiety_pct": 0,
		"companion_exhausted": true,
	})
	_expect(not bool(empty_companion.get("visible", true)), "empty companion id should hide the strip instead of reading as exhausted")


func _verify_strip_layout() -> void:
	var affinity_rect := Rect2(Vector2(16.0, 12.0), Vector2(230.0, max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)))
	for snapshot in [
		{"state": "companion", "pet_id": "maribo", "satiety_pct": 73, "companion_exhausted": false},
		{"state": "companion", "pet_id": "maribo", "satiety_pct": 0, "companion_exhausted": true, "satiety_exhaustion_ratio": 1.0},
	]:
		var layout := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_layout_for_tests(ThemeDB.fallback_font, affinity_rect, snapshot, 1.0)
		_expect(not layout.is_empty(), "visible satiety snapshot should build a layout")
		var label_rect: Rect2 = layout.get("label_rect", Rect2())
		var meter_rect: Rect2 = layout.get("meter_rect", Rect2())
		var value_rect: Rect2 = layout.get("value_rect", Rect2())
		_expect(is_equal_approx(meter_rect.size.y, CharacterInfoOverlayLingpetPresenter.SATIETY_METER_HEIGHT), "satiety strip should keep an 8px meter")
		# The 포만 label now lives in the right-hand annotation column (beside/after
		# the meter), so it must sit at or right of the meter's end, never overlap it.
		_expect(label_rect.size.x <= 1.0 or label_rect.position.x >= meter_rect.end.x - 0.01, "satiety label should sit in the right annotation column, not overlap the meter")
		_expect(meter_rect.end.x <= value_rect.position.x + 0.01, "satiety meter should not overlap the right value text")
		_expect(label_rect.size.x <= 1.0 or value_rect.position.x >= label_rect.end.x - 0.01, "satiety value should follow the label without overlap")
		_expect(meter_rect.end.y <= affinity_rect.end.y + 0.01, "satiety meter should fit inside the expanded affinity band")
		# Alignment seal: the 포만 meter must share the 교감 meter's exact left edge
		# and width so the two bars read as one clean stack (the reported ragged look).
		_expect(is_equal_approx(meter_rect.position.x, affinity_rect.position.x), "satiety meter should share the affinity meter's left edge")
		_expect(is_equal_approx(meter_rect.size.x, CharacterInfoOverlayLingpetPresenter.lingpet_progress_meter_width(affinity_rect)), "satiety meter should share the affinity meter width")


func _verify_bar_hover_zones() -> void:
	var affinity_rect := Rect2(Vector2(16.0, 12.0), Vector2(230.0, max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)))
	var affinity_zone: Rect2 = CharacterInfoOverlayLingpetPresenter.affinity_bar_hover_rect(affinity_rect)
	var satiety_zone: Rect2 = CharacterInfoOverlayLingpetPresenter.satiety_bar_hover_rect(affinity_rect)
	# Both zones span the full band width and start at its left edge.
	_expect(is_equal_approx(affinity_zone.position.x, affinity_rect.position.x) and is_equal_approx(affinity_zone.size.x, affinity_rect.size.x), "교감 hover zone should span the full band width")
	_expect(is_equal_approx(satiety_zone.position.x, affinity_rect.position.x) and is_equal_approx(satiety_zone.size.x, affinity_rect.size.x), "포만도 hover zone should span the full band width")
	# The two zones must not overlap: 교감 ends exactly where 포만도 begins.
	_expect(affinity_zone.end.y <= satiety_zone.position.y + 0.01, "교감 and 포만도 hover zones must not overlap")
	# The affinity meter (y+18..+26) lands in the 교감 zone; the satiety meter
	# (strip_y = y+30 .. +38) lands in the 포만도 zone — cross-check both.
	var affinity_meter_probe := Vector2(affinity_rect.get_center().x, affinity_rect.position.y + 22.0)
	var satiety_meter_probe := Vector2(affinity_rect.get_center().x, affinity_rect.position.y + 34.0)
	_expect(affinity_zone.has_point(affinity_meter_probe) and not satiety_zone.has_point(affinity_meter_probe), "affinity meter point should hit only the 교감 hover zone")
	_expect(satiety_zone.has_point(satiety_meter_probe) and not affinity_zone.has_point(satiety_meter_probe), "satiety meter point should hit only the 포만도 hover zone")


func _verify_unlock_gate_survives_expanded_band() -> void:
	var skill_row_h: float = clamp(CONTENT_RECT.size.y * 0.22, 58.0, 78.0)
	var unlock_band_h: float = clamp(CONTENT_RECT.size.y * 0.18, CharacterInfoOverlayLingpetPresenter.UNLOCK_CHOICE_BAND_MIN_HEIGHT, CharacterInfoOverlayLingpetPresenter.UNLOCK_CHOICE_BAND_MAX_HEIGHT)
	var art_rect: Rect2 = CharacterInfoOverlayLingpetPresenter.companion_art_rect(
		CONTENT_RECT,
		skill_row_h + unlock_band_h + CharacterInfoOverlayLingpetPresenter.RING_CORE_ROW_HEIGHT,
		CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT
	)
	var affinity_rect := Rect2(
		art_rect.position.x,
		art_rect.end.y + 4.0,
		art_rect.size.x,
		max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)
	)
	var ring_core_row_rect := Rect2(
		affinity_rect.position.x,
		affinity_rect.end.y + 4.0,
		affinity_rect.size.x,
		CharacterInfoOverlayLingpetPresenter.RING_CORE_ROW_HEIGHT
	)
	var icon_count := 2
	var icon_gap := 9.0
	var icon_size: float = clamp((CONTENT_RECT.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_y: float = CONTENT_RECT.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	var unlock_height: float = max(0.0, icon_y - ring_core_row_rect.end.y - 8.0)
	_expect(unlock_height >= 42.0, "expanded affinity band should still leave at least the 42px unlock-choice gate")


func _finish() -> void:
	if _failures.is_empty():
		print("character_info_lingpet_satiety_bar_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
