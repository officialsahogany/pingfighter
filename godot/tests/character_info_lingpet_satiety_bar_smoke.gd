extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

const CONTENT_RECT := Rect2(Vector2(24.0, 22.0), Vector2(300.0, 360.0))

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contract()
	_verify_runtime_snapshot_merge()
	_verify_live_stowed_runtime_merge()
	_verify_duration_states()
	_verify_strip_layout()
	_verify_bar_hover_zones()
	_verify_unlock_gate_survives_expanded_band()
	call_deferred("_finish")


func _verify_source_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var vitality_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	_expect(presenter_source.find("const AFFINITY_BAND_HEIGHT := 50.0") >= 0, "TAB lingpet affinity band should be expanded for the satiety strip")
	_expect(presenter_source.find("max(24.0, affinity_band_h - 10.0)") >= 0, "TAB lingpet affinity rect should keep the 42px unlock-choice gate after the expanded band")
	_expect(vitality_source.find("duration_pool_pct") >= 0, "TAB vitality projection should consume the shared duration-pool snapshot")
	_expect(vitality_source.find("guardian_stowed") >= 0, "TAB vitality projection should retain stowed state without hiding the duration strip")
	_expect(vitality_source.find("탈진 Zzz") < 0, "TAB duration projection should remove the retired exhaustion presentation")
	_expect(presenter_source.find("lingpet_satiety_pct") < 0, "TAB satiety strip should not read the owner-only lingpet_satiety_pct key")
	_expect(presenter_source.find("CharacterInfoOverlayLingpetVitalityProjection.merge_runtime_snapshot") >= 0, "TAB presenter should delegate runtime satiety merging")
	_expect(presenter_source.find("CharacterInfoOverlayLingpetVitalityProjection.get_strip_state") >= 0, "TAB presenter should delegate satiety state projection")
	_expect(frame_source.find("merge_runtime_satiety_snapshot") >= 0, "TAB frame presenter should merge the existing lingpet runtime snapshot into the panel snapshot")
	_expect(frame_source.find("lingpet_satiety_pct") < 0, "TAB frame presenter should not read the owner-only lingpet_satiety_pct key")
	# Bar hover tooltips: the caller must thread mouse/hover into draw_affinity_status
	# and the drawer must publish both bar tooltip bodies through _fill_hover_data.
	_expect(presenter_source.find("draw_affinity_status(canvas, font, affinity_rect, snapshot, stat_buff_color, empty_text_color, accent_blue, ui_text_scale, mouse_pos, hover_data)") >= 0, "TAB affinity/satiety draw should receive mouse_pos + hover_data for bar tooltips")
	_expect(presenter_source.find("이번 판 동안 수호령과 쌓은 교감 수치입니다") >= 0, "교감 bar hover should publish an affinity tooltip body")
	_expect(presenter_source.find("수호령의 남은 소환 지속시간입니다. 소환 중에는 줄고") >= 0, "duration bar hover should publish the shared-pool tooltip body")
	var tooltip_key := "수호령의 남은 소환 지속시간입니다. 소환 중에는 줄고 수납 중에는 천천히 회복됩니다. 0이 되면 자동으로 수납됩니다."
	_expect(LanguageSettingsData.EXACT_TEXT_EN.has(tooltip_key), "English exact text should localize the duration tooltip")
	_expect(LanguageSettingsData.EXACT_TEXT_ZH.has(tooltip_key), "Chinese exact text should localize the duration tooltip")
	_expect(LanguageSettingsData.EXACT_TEXT_JA.has(tooltip_key), "Japanese exact text should localize the duration tooltip")
	_expect(LanguageSettingsData.EXACT_TEXT_ES.has(tooltip_key), "Spanish exact text should localize the duration tooltip")
	_expect(LanguageSettingsData.EXACT_TEXT_PT_BR_OVERRIDES.has(tooltip_key), "Brazilian Portuguese overrides should localize the duration tooltip")
	_expect(LanguageSettingsData.EXACT_TEXT_RU_OVERRIDES.has(tooltip_key), "Russian overrides should localize the duration tooltip")


func _verify_runtime_snapshot_merge() -> void:
	var panel_snapshot := {
		"state": "companion",
		"pet_id": "maribo",
	}
	var runtime_snapshot := {
		"duration_pool_pct": 41,
		"guardian_stowed": true,
	}
	CharacterInfoOverlayLingpetPresenter.merge_runtime_satiety_snapshot(panel_snapshot, runtime_snapshot)
	_expect(int(panel_snapshot.get("duration_pool_pct", -1)) == 41, "panel snapshot should receive duration_pool_pct from the runtime snapshot")
	_expect(bool(panel_snapshot.get("guardian_stowed", false)), "panel snapshot should preserve guardian_stowed for the visible stowed strip")


func _verify_live_stowed_runtime_merge() -> void:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	var registry := Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	registry.instances["lingpet_egg_runtime"] = runtime
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "live TAB fixture should activate Maribo")
	runtime.update(6.1, owner, registry)
	runtime.set_duration_pool_for_tests(30.0, 60.0)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "live TAB fixture should consume the stow toggle")
	_expect(runtime.is_guardian_stowed(), "live TAB fixture should enter stow")
	var panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	_expect(str(panel_snapshot.get("state", "")) == "none", "counterproof: owner-only TAB snapshot should collapse to none while stowed")
	var runtime_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(runtime_snapshot.get("guardian_stowed", false)), "live runtime snapshot should publish guardian_stowed")
	_expect(str(runtime_snapshot.get("state", "")) == "companion", "live runtime snapshot should preserve roster state")
	_expect(str(runtime_snapshot.get("pet_id", "")) == "maribo", "live runtime snapshot should preserve roster pet id")
	CharacterInfoOverlayLingpetPresenter.merge_runtime_satiety_snapshot(panel_snapshot, runtime_snapshot)
	_expect(str(panel_snapshot.get("state", "")) == "companion", "runtime merge should restore the stowed companion panel")
	_expect(str(panel_snapshot.get("pet_id", "")) == "maribo", "runtime merge should restore the stowed panel pet id")
	_expect(str(panel_snapshot.get("subtitle", "")) == "수납 중", "stowed companion panel should use the approved subtitle")
	var slot_tabs: Array = panel_snapshot.get("slot_tabs", []) as Array
	_expect(not slot_tabs.is_empty() and str(panel_snapshot.get("title", "")) == str((slot_tabs[0] as Dictionary).get("name", "")), "stowed panel title should resolve from the live roster tab")
	var strip: Dictionary = CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state(panel_snapshot)
	_expect(bool(strip.get("visible", false)), "live stowed panel should keep the duration strip visible")
	_expect(bool(strip.get("stowed", false)), "live stowed panel should preserve the stowed marker")
	_expect(int(strip.get("pct", -1)) == 50, "live stowed panel should expose the recovering 50 percent pool")
	if runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
	registry.instances.clear()


func _verify_duration_states() -> void:
	var normal := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"duration_pool_pct": 73,
		"guardian_stowed": false,
	})
	_expect(bool(normal.get("visible", false)), "summoned guardian should show the TAB duration strip")
	_expect(str(normal.get("label", "")) == "지속시간", "duration strip should use the approved label")
	_expect(str(normal.get("color_key", "")) == "normal", "duration above 50 should use the normal color key")
	_expect(str(normal.get("value", "")) == "73%", "duration strip should show the quantized percent")

	var warning := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"duration_pool_pct": 50,
	})
	_expect(str(warning.get("color_key", "")) == "warning", "duration at 50 should enter the yellow warning color key")

	var critical := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"duration_pool_pct": 20,
	})
	_expect(str(critical.get("color_key", "")) == "critical", "duration at 20 should enter the red critical color key")

	var stowed := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "maribo",
		"duration_pool_pct": 0,
		"guardian_stowed": true,
	})
	_expect(bool(stowed.get("visible", false)), "stowed guardian should keep the TAB duration strip visible")
	_expect(bool(stowed.get("stowed", false)), "duration strip should retain the stowed marker")
	_expect(str(stowed.get("color_key", "")) == "critical", "empty shared pool should use the red critical color key")
	_expect(str(stowed.get("value", "")) == "0%", "stowed empty pool should render 0 percent without the retired exhaustion label")

	var no_pet := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "none",
		"duration_pool_pct": 0,
	})
	_expect(not bool(no_pet.get("visible", true)), "no-pet state should hide the strip even though duration is also 0")

	var empty_companion := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state({
		"state": "companion",
		"pet_id": "",
		"duration_pool_pct": 0,
	})
	_expect(not bool(empty_companion.get("visible", true)), "empty companion id should hide the strip instead of reading as exhausted")


func _verify_strip_layout() -> void:
	var affinity_rect := Rect2(Vector2(16.0, 12.0), Vector2(230.0, max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)))
	for snapshot in [
		{"state": "companion", "pet_id": "maribo", "duration_pool_pct": 73, "guardian_stowed": false},
		{"state": "companion", "pet_id": "maribo", "duration_pool_pct": 0, "guardian_stowed": true},
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
		skill_row_h + unlock_band_h,
		CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT
	)
	var affinity_rect := Rect2(
		art_rect.position.x,
		art_rect.end.y + 4.0,
		art_rect.size.x,
		max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)
	)
	var icon_count := 2
	var icon_gap := 9.0
	var icon_size: float = clamp((CONTENT_RECT.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_y: float = CONTENT_RECT.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	var unlock_height: float = max(0.0, icon_y - affinity_rect.end.y - 8.0)
	_expect(unlock_height >= 42.0, "retiring the ring-core row should still leave at least the 42px unlock-choice gate")


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
