extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

const CONTENT_RECT := Rect2(Vector2(24.0, 22.0), Vector2(300.0, 360.0))
const STOW_DISPLAY_INVARIANT_KEYS := [
	"title",
	"body",
	"gauge_gain_bonus_pct",
	"companion_player_speed_bonus_pct",
	"companion_starpoint_tracking_chance_pct",
	"companion_ring_dash_chance_pct",
	"gauge_gain_bonus_icon_path",
	"companion_hit_gauge_gain",
	"companion_skill_id",
	"companion_skill_name",
	"companion_skill_description",
	"companion_skill_card_path",
	"companion_skill_icon_path",
	"companion_skill_cooldown_duration",
	"companion_skill_level",
	"companion_skill_max_level",
	"companion_skill_id_1",
	"companion_skill_name_1",
	"companion_skill_description_1",
	"companion_skill_card_path_1",
	"companion_skill_icon_path_1",
	"companion_skill_cooldown_duration_1",
	"companion_skill_level_1",
	"companion_skill_max_level_1",
	"companion_passive_skill_id",
	"companion_passive_skill_name",
	"companion_passive_skill_description",
	"companion_passive_skill_icon_path",
	"companion_passive_skill_level",
	"companion_passive_skill_max_level",
	"companion_passive_skill_id_1",
	"companion_passive_skill_name_1",
	"companion_passive_skill_description_1",
	"companion_passive_skill_icon_path_1",
	"companion_passive_skill_level_1",
	"companion_passive_skill_max_level_1",
	"companion_patrol_speed_default",
	"companion_patrol_speed_min",
	"companion_patrol_speed_max",
	"companion_catch_width",
	"companion_catch_height",
	"companion_defense_rate",
	"companion_appearance_rate",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contract()
	_verify_runtime_snapshot_merge()
	_verify_live_stowed_runtime_merge()
	_verify_duration_states()
	_verify_strip_layout()
	_verify_duration_hover_zone()
	_verify_unlock_gate_survives_expanded_band()
	call_deferred("_finish")


func _verify_source_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var vitality_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	_expect(presenter_source.find("const DURATION_BAND_HEIGHT := 28.0") >= 0, "TAB guardian panel should reserve one compact duration band")
	_expect(presenter_source.find("max(20.0, duration_band_h - 4.0)") >= 0, "TAB duration rect should preserve the unlock-choice gate")
	_expect(vitality_source.find("duration_pool_pct") >= 0, "TAB vitality projection should consume the shared duration-pool snapshot")
	_expect(vitality_source.find("guardian_stowed") >= 0, "TAB vitality projection should retain stowed state without hiding the duration strip")
	_expect(vitality_source.find("탈진 Zzz") < 0, "TAB duration projection should remove the retired exhaustion presentation")
	_expect(presenter_source.find("lingpet_satiety_pct") < 0, "TAB satiety strip should not read the owner-only lingpet_satiety_pct key")
	_expect(presenter_source.find("CharacterInfoOverlayLingpetVitalityProjection.merge_runtime_snapshot") >= 0, "TAB presenter should delegate runtime satiety merging")
	_expect(presenter_source.find("CharacterInfoOverlayLingpetVitalityProjection.get_strip_state") >= 0, "TAB presenter should delegate satiety state projection")
	_expect(frame_source.find("merge_runtime_display_snapshot") >= 0, "TAB frame presenter should merge the runtime-owned display snapshot into every panel surface")
	_expect(frame_source.find("lingpet_satiety_pct") < 0, "TAB frame presenter should not read the owner-only lingpet_satiety_pct key")
	_expect(presenter_source.find("draw_duration_status(canvas, font, duration_rect, snapshot, stat_buff_color, empty_text_color, ui_text_scale, mouse_pos, hover_data)") >= 0, "TAB duration draw should receive mouse_pos + hover_data")
	_expect(presenter_source.find("affinity_level") < 0 and presenter_source.find("교감") < 0, "retired affinity presentation must not survive in the TAB presenter")
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
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(panel_snapshot, runtime_snapshot)
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
	_expect(runtime.debug_grant_and_activate_pet(
		"maribo",
		owner,
		false,
		"maribo_hydro_sphere",
		"lingpet_resonance_boost",
		registry,
		3,
		4,
		"maribo_bubble_trap",
		"lingpet_afterglow_leak",
		2,
		5
	), "live TAB fixture should activate Maribo with explicit active and passive levels")
	runtime.update(6.1, owner, registry)
	runtime.set_duration_pool_for_tests(30.0, 60.0)
	var summoned_panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	var summoned_runtime_snapshot: Dictionary = runtime.get_snapshot()
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(summoned_panel_snapshot, summoned_runtime_snapshot)
	var summoned_display_values := _capture_display_values(summoned_panel_snapshot)
	var summoned_stats := _build_display_stats(summoned_panel_snapshot)
	var summoned_skill_specs := CharacterInfoOverlayLingpetPresenter.get_skill_specs(summoned_panel_snapshot, Color(0.42, 0.96, 0.78))
	_expect(str(summoned_panel_snapshot.get("subtitle", "")) == "동행 중", "summoned TAB fixture should expose only the active status label")
	_expect(summoned_skill_specs.size() == 3, "summoned TAB fixture should expose the available active slot and both passive slots")
	_expect(int(summoned_panel_snapshot.get("companion_skill_level", 0)) == 3, "summoned TAB fixture should expose the real active level")
	_expect(int(summoned_panel_snapshot.get("companion_passive_skill_level", 0)) == 4, "summoned TAB fixture should expose the real primary passive level")
	_expect(int(summoned_panel_snapshot.get("companion_passive_skill_level_1", 0)) == 5, "summoned TAB fixture should expose the real second passive level")
	_expect(is_equal_approx(float(summoned_panel_snapshot.get("companion_defense_rate", 0.0)), 0.30), "summoned TAB fixture should expose Maribo's real defense rate")
	_expect(is_equal_approx(float(summoned_panel_snapshot.get("companion_hit_gauge_gain", 0.0)), 40.0), "summoned TAB fixture should expose the real hit gauge gain")
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
	_expect(str(runtime_snapshot.get("companion_skill_id", "")) == "", "stow must keep suppressing the public gameplay skill id")
	_expect(float(runtime_snapshot.get("companion_defense_rate", -1.0)) == 0.0, "stow must keep suppressing the public gameplay defense rate")
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(panel_snapshot, runtime_snapshot)
	_expect(str(panel_snapshot.get("state", "")) == "companion", "runtime merge should restore the stowed companion panel")
	_expect(str(panel_snapshot.get("pet_id", "")) == "maribo", "runtime merge should restore the stowed panel pet id")
	_expect(str(panel_snapshot.get("subtitle", "")) == "수납 중", "stowed companion panel should use the approved subtitle")
	_expect(_capture_display_values(panel_snapshot) == summoned_display_values, "real summoned-to-stowed path should preserve every TAB display value")
	_expect(_build_display_stats(panel_snapshot) == summoned_stats, "real summoned-to-stowed path should preserve every rendered stats row")
	_expect(CharacterInfoOverlayLingpetPresenter.get_skill_specs(panel_snapshot, Color(0.42, 0.96, 0.78)) == summoned_skill_specs, "real summoned-to-stowed path should preserve every skill card and level")
	var slot_tabs: Array = panel_snapshot.get("slot_tabs", []) as Array
	_expect(not slot_tabs.is_empty() and str(panel_snapshot.get("title", "")) == str((slot_tabs[0] as Dictionary).get("name", "")), "stowed panel title should resolve from the live roster tab")
	var strip: Dictionary = CharacterInfoOverlayLingpetPresenter.get_satiety_strip_state(panel_snapshot)
	_expect(bool(strip.get("visible", false)), "live stowed panel should keep the duration strip visible")
	_expect(bool(strip.get("stowed", false)), "live stowed panel should preserve the stowed marker")
	_expect(int(strip.get("pct", -1)) == 50, "live stowed panel should expose the recovering 50 percent pool")
	var owner_only_counterproof: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	var suppressed_runtime_counterproof := runtime_snapshot.duplicate(true)
	suppressed_runtime_counterproof.erase("character_info_display_snapshot")
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(owner_only_counterproof, suppressed_runtime_counterproof)
	_expect(_capture_display_values(owner_only_counterproof) != summoned_display_values, "counterproof: reconnecting TAB to stow-suppressed keys must lose display values")
	print("stowed TAB invariant surfaces: duration, movement/body, defense/appearance, gauge bonuses, active/passive slots and levels")
	if runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
	registry.instances.clear()


func _capture_display_values(snapshot: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for key in STOW_DISPLAY_INVARIANT_KEYS:
		values[key] = snapshot.get(key)
	return values


func _build_display_stats(snapshot: Dictionary) -> Array:
	return CharacterInfoOverlayLingpetPresenter.build_stats(
		snapshot,
		Color(0.92, 0.72, 0.24),
		Color(0.72, 0.76, 0.82),
		Color(0.46, 0.50, 0.58),
		Color(0.42, 0.96, 0.78),
		4.0,
		3,
		"defense",
		Rect2(Vector2.ZERO, Vector2(560.0, 480.0))
	)


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
	var duration_rect := Rect2(Vector2(16.0, 12.0), Vector2(230.0, max(20.0, CharacterInfoOverlayLingpetPresenter.DURATION_BAND_HEIGHT - 4.0)))
	for snapshot in [
		{"state": "companion", "pet_id": "maribo", "duration_pool_pct": 73, "guardian_stowed": false},
		{"state": "companion", "pet_id": "maribo", "duration_pool_pct": 0, "guardian_stowed": true},
	]:
		var layout := CharacterInfoOverlayLingpetPresenter.get_satiety_strip_layout_for_tests(ThemeDB.fallback_font, duration_rect, snapshot, 1.0)
		_expect(not layout.is_empty(), "visible satiety snapshot should build a layout")
		var label_rect: Rect2 = layout.get("label_rect", Rect2())
		var meter_rect: Rect2 = layout.get("meter_rect", Rect2())
		var value_rect: Rect2 = layout.get("value_rect", Rect2())
		_expect(is_equal_approx(meter_rect.size.y, CharacterInfoOverlayLingpetPresenter.SATIETY_METER_HEIGHT), "satiety strip should keep an 8px meter")
		# The duration label lives in the right-hand annotation column (beside/after
		# the meter), so it must sit at or right of the meter's end, never overlap it.
		_expect(label_rect.size.x <= 1.0 or label_rect.position.x >= meter_rect.end.x - 0.01, "satiety label should sit in the right annotation column, not overlap the meter")
		_expect(meter_rect.end.x <= value_rect.position.x + 0.01, "satiety meter should not overlap the right value text")
		_expect(label_rect.size.x <= 1.0 or value_rect.position.x >= label_rect.end.x - 0.01, "satiety value should follow the label without overlap")
		_expect(meter_rect.end.y <= duration_rect.end.y + 0.01, "duration meter should fit inside its compact band")
		_expect(is_equal_approx(meter_rect.position.x, duration_rect.position.x), "duration meter should align to the band left edge")
		_expect(is_equal_approx(meter_rect.size.x, CharacterInfoOverlayLingpetPresenter.lingpet_progress_meter_width(duration_rect)), "duration meter should use the shared progress width")


func _verify_duration_hover_zone() -> void:
	var duration_rect := Rect2(Vector2(16.0, 12.0), Vector2(230.0, max(20.0, CharacterInfoOverlayLingpetPresenter.DURATION_BAND_HEIGHT - 4.0)))
	var duration_zone: Rect2 = CharacterInfoOverlayLingpetPresenter.satiety_bar_hover_rect(duration_rect)
	_expect(duration_zone == duration_rect, "duration tooltip should own the full compact band")
	_expect(duration_zone.has_point(duration_rect.get_center()), "duration meter center should open the duration tooltip")


func _verify_unlock_gate_survives_expanded_band() -> void:
	var skill_row_h: float = clamp(CONTENT_RECT.size.y * 0.22, 58.0, 78.0)
	var unlock_band_h: float = clamp(CONTENT_RECT.size.y * 0.18, CharacterInfoOverlayLingpetPresenter.UNLOCK_CHOICE_BAND_MIN_HEIGHT, CharacterInfoOverlayLingpetPresenter.UNLOCK_CHOICE_BAND_MAX_HEIGHT)
	var art_rect: Rect2 = CharacterInfoOverlayLingpetPresenter.companion_art_rect(
		CONTENT_RECT,
		skill_row_h + unlock_band_h,
		CharacterInfoOverlayLingpetPresenter.DURATION_BAND_HEIGHT
	)
	var duration_rect := Rect2(
		art_rect.position.x,
		art_rect.end.y + 4.0,
		art_rect.size.x,
		max(20.0, CharacterInfoOverlayLingpetPresenter.DURATION_BAND_HEIGHT - 4.0)
	)
	var icon_count := 2
	var icon_gap := 9.0
	var icon_size: float = clamp((CONTENT_RECT.size.x - 24.0 - icon_gap * float(icon_count - 1)) / float(icon_count), 38.0, 58.0)
	var icon_y: float = CONTENT_RECT.end.y - skill_row_h + (skill_row_h - icon_size) * 0.48
	var unlock_height: float = max(0.0, icon_y - duration_rect.end.y - 8.0)
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
