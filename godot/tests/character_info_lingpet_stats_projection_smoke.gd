extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetStatsProjection := preload("res://scripts/hud/character_info_overlay_lingpet_stats_projection.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

const HATCH_REQUIRED_HITS := 10
const STAT_COLOR := Color(0.45, 1.0, 0.68, 1.0)

var _failures: Array[String] = []


func _init() -> void:
	_verify_none_and_egg_rows()
	_verify_companion_rows_and_budget()
	_verify_cache_invalidation_surface()
	_verify_presenter_boundary_contract()
	if _failures.is_empty():
		print("character_info_lingpet_stats_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_none_and_egg_rows() -> void:
	var none_rows := _build({"state": "none"}, Rect2())
	_expect(none_rows.size() == 1 and str((none_rows[0] as Dictionary).get("value", "")) == "미획득", "none state should project one unowned row")
	var egg_rows := _build({"state": "egg", "hatch_hits": 4, "required_hits": 12}, Rect2())
	_expect(egg_rows.size() == 2, "egg state should project status and hatch progress")
	_expect(str((egg_rows[1] as Dictionary).get("value", "")) == "4 / 12", "egg progress should preserve current/required hits")


func _verify_companion_rows_and_budget() -> void:
	var snapshot := _full_snapshot()
	var spacious_rows := _build(snapshot, Rect2(Vector2.ZERO, Vector2(560.0, 360.0)))
	_expect(_has_label(spacious_rows, "이동 속도"), "companion rows should include movement speed")
	_expect(_has_label(spacious_rows, "방어율"), "patrol companion should include defense rate")
	_expect(_has_label(spacious_rows, "2nd 액티브"), "spacious row budget should include second active cooldown")
	_expect(_has_label(spacious_rows, "교감"), "companion rows should always end with affinity")
	var tight_rows := _build(snapshot, Rect2(Vector2.ZERO, Vector2(560.0, 340.0)))
	_expect(not _has_label(tight_rows, "2nd 액티브"), "tight row budget should yield the second active cooldown")
	_expect(_has_label(tight_rows, "교감"), "tight row budget should retain affinity")
	var flight_snapshot := snapshot.duplicate(true)
	flight_snapshot["companion_defense_rate"] = 0.0
	flight_snapshot["companion_appearance_rate"] = 0.35
	var flight_rows := _build(flight_snapshot, Rect2(Vector2.ZERO, Vector2(560.0, 360.0)))
	_expect(not _has_label(flight_rows, "방어율") and _has_label(flight_rows, "출현율"), "flight companion should replace defense with appearance rate")


func _verify_cache_invalidation_surface() -> void:
	var snapshot := _full_snapshot()
	var base_hash := CharacterInfoOverlayLingpetStatsProjection.get_stats_cache_hash(snapshot, HATCH_REQUIRED_HITS)
	for key in ["companion_skill_id_1", "companion_passive_skill_id_1", "ring_core_tier", "affinity_chip_count", "affinity_points"]:
		var changed := snapshot.duplicate(true)
		changed[key] = str(changed.get(key, "")) + "_changed" if key.ends_with("id_1") else float(changed.get(key, 0.0)) + 1.0
		_expect(CharacterInfoOverlayLingpetStatsProjection.get_stats_cache_hash(changed, HATCH_REQUIRED_HITS) != base_hash, "stats hash should invalidate on %s" % key)
	var spacious := CharacterInfoOverlayLingpetStatsProjection.build_stats_cached(snapshot, {}, Color.WHITE, Color.WHITE, Color.WHITE, STAT_COLOR, 60.0, HATCH_REQUIRED_HITS, "", Rect2(Vector2.ZERO, Vector2(560.0, 360.0)))
	var tight := CharacterInfoOverlayLingpetStatsProjection.build_stats_cached(snapshot, spacious, Color.WHITE, Color.WHITE, Color.WHITE, STAT_COLOR, 60.0, HATCH_REQUIRED_HITS, "", Rect2(Vector2.ZERO, Vector2(560.0, 340.0)))
	_expect(int(spacious.get("hash", 0)) != int(tight.get("hash", 0)), "row-budget dimensions should participate in cached projection hash")


func _verify_presenter_boundary_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var projection_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_stats_projection.gd")
	_expect(_function_body(presenter_source, "static func build_stats(").find("CharacterInfoOverlayLingpetStatsProjection.build_stats") >= 0, "presenter build-stats facade should delegate")
	_expect(_function_body(presenter_source, "static func build_stats_cached(").find("CharacterInfoOverlayLingpetStatsProjection.build_stats_cached") >= 0, "presenter cached-stats facade should delegate")
	_expect(_function_body(presenter_source, "static func get_stats_cache_hash(").find("CharacterInfoOverlayLingpetStatsProjection.get_stats_cache_hash") >= 0, "presenter stats-hash facade should delegate")
	_expect(projection_source.find("CanvasItem") < 0 and projection_source.find("FileAccess") < 0, "stats projection should remain draw- and I/O-free")
	var expected_rows := CharacterInfoOverlayLingpetStatsProjection.build_stats(_full_snapshot(), Color.WHITE, Color.WHITE, Color.WHITE, STAT_COLOR, 60.0, HATCH_REQUIRED_HITS, "")
	_expect(CharacterInfoOverlayLingpetPresenter.build_stats(_full_snapshot(), Color.WHITE, Color.WHITE, Color.WHITE, STAT_COLOR, 60.0, HATCH_REQUIRED_HITS, "") == expected_rows, "presenter facade should preserve exact projected rows")


func _full_snapshot() -> Dictionary:
	return {
		"state": "companion",
		"title": "파루키라스",
		"companion_patrol_speed_default": 120.0,
		"companion_patrol_speed_min": 70.0,
		"companion_patrol_speed_max": 135.0,
		"companion_catch_width": 100.0,
		"companion_catch_height": 44.0,
		"companion_hit_gauge_gain": 40.0,
		"companion_skill_id": "active_1",
		"companion_skill_name": "브레스",
		"companion_skill_cooldown_duration": 40.0,
		"companion_skill_id_1": "active_2",
		"companion_skill_name_1": "윙",
		"companion_skill_cooldown_duration_1": 17.0,
		"companion_passive_skill_id_1": "passive_2",
		"companion_passive_skill_name_1": "순풍",
		"companion_defense_rate": 0.25,
		"companion_appearance_rate": 0.0,
		"affinity_level": 25,
		"affinity_points": 15.0,
		"affinity_next_requirement": 50.0,
		"affinity_next_label": "보상",
		"ring_core_tier": 3,
		"affinity_chip_count": 4,
	}


func _build(snapshot: Dictionary, rect: Rect2) -> Array:
	return CharacterInfoOverlayLingpetStatsProjection.build_stats(snapshot, Color.WHITE, Color.WHITE, Color.WHITE, STAT_COLOR, 60.0, HATCH_REQUIRED_HITS, "방어 툴팁", rect)


func _has_label(rows: Array, token: String) -> bool:
	for row_value in rows:
		if row_value is Dictionary and str((row_value as Dictionary).get("label", "")).find(token) >= 0:
			return true
	return false


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
