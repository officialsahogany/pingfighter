extends SceneTree

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

const CANONICAL_PERK_ID := "bulletproof_hat"
const RETIRED_PERK_ID := "spiked_helmet"


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_single_catalog_entry_and_presentation()
	_verify_legacy_level_migration()
	_verify_legacy_fusion_migration()
	_verify_shared_runtime_value()
	_verify_round_reset_preserves_posture_projection()
	_verify_stun_duration_consumption()
	_verify_knockback_distance_and_duration_consumption()
	_verify_legacy_items_remain_compatible()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("posture_correction_mugong_merge_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_single_catalog_entry_and_presentation() -> void:
	var catalog := RuntimePerkCatalog.new()
	var iron_heart: Dictionary = catalog.get_perk_data(CANONICAL_PERK_ID)
	_expect(str(iron_heart.get("name", "")) == "철심공", "the merged Mugong should keep the Iron Heart Art name")
	var descriptions: Dictionary = iron_heart.get("descriptions", {}) as Dictionary
	_expect(str(descriptions.get(1, "")).contains("자세보정"), "Iron Heart Art level text should expose Posture Correction")
	_expect(str(iron_heart.get("detail", "")).contains("스턴") and str(iron_heart.get("detail", "")).contains("넉백"), "Iron Heart Art detail should explain both stun and knockback recovery")
	_expect(catalog.get_perk_data(RETIRED_PERK_ID).is_empty(), "Thousand-Weight Stance should no longer resolve as a standalone Mugong")
	_expect(not PerkFusionCatalog.new().is_candidate(RETIRED_PERK_ID, 5, catalog), "retired Thousand-Weight Stance should not remain a fusion candidate")
	_expect(not RuntimePerkIconRenderer.PERK_ICON_PATHS.has(RETIRED_PERK_ID), "retired Thousand-Weight Stance should have no runtime Mugong icon route")
	for name_map_value: Variant in [
		LanguageSettingsData.PERK_NAME_EN,
		LanguageSettingsData.PERK_NAME_ZH,
		LanguageSettingsData.PERK_NAME_JA,
		LanguageSettingsData.PERK_NAME_ES,
		LanguageSettingsData.PERK_NAME_PT_BR,
		LanguageSettingsData.PERK_NAME_RU,
	]:
		_expect(not (name_map_value as Dictionary).has(RETIRED_PERK_ID), "retired Thousand-Weight Stance should be absent from localized Mugong names")


func _verify_legacy_level_migration() -> void:
	var source_only: Dictionary = PerkConversionValues.sanitize_runtime_levels({RETIRED_PERK_ID: 3})
	_expect(int(source_only.get(CANONICAL_PERK_ID, 0)) == 3, "legacy Thousand-Weight levels should move to Iron Heart Art")
	_expect(not source_only.has(RETIRED_PERK_ID), "legacy level migration should remove the retired source id")

	var state := RuntimePerkState.new()
	var restore_result: Dictionary = state.apply_unlock_save_snapshot({
		"version": 1,
		"runtime_skill_levels": {CANONICAL_PERK_ID: 3, RETIRED_PERK_ID: 4},
	})
	var levels: Dictionary = restore_result.get("runtime_skill_levels", {}) as Dictionary
	_expect(int(levels.get(CANONICAL_PERK_ID, 0)) == 5, "merged legacy levels should add together and cap at Iron Heart Art Lv.5")
	_expect(not levels.has(RETIRED_PERK_ID), "restored levels should not keep the retired source id")
	_expect(int(restore_result.get("removed_retired_perks", 0)) == 1, "restore should report the migrated retired Mugong entry")


func _verify_legacy_fusion_migration() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {CANONICAL_PERK_ID: 5, "item_luck": 5}
	var restore_result: Dictionary = state.restore_perk_fusion_snapshot({
		"records": [{
			"fusion_id": "fusion_posture_legacy",
			"sources": [RETIRED_PERK_ID, "item_luck"],
			"outcome": "side_effect",
			"option_penalties": {
				RETIRED_PERK_ID: {"knockback_resist_pct": {"multiplier": 0.8}},
			},
		}],
		"next_fusion_index": 1,
		"fusion_revision": 1,
	}, RuntimePerkCatalog.new())
	_expect(int(restore_result.get("kept", 0)) == 1, "legacy Thousand-Weight fusion should migrate to Iron Heart Art when the merged source is owned")
	var records: Array = state.get_perk_fusion_snapshot().get("records", []) as Array
	if records.size() != 1:
		return
	var record: Dictionary = records[0] as Dictionary
	var sources: Array = record.get("sources", []) as Array
	_expect(CANONICAL_PERK_ID in sources and RETIRED_PERK_ID not in sources, "migrated fusion record should use the canonical Iron Heart Art source id")
	var penalties: Dictionary = record.get("option_penalties", {}) as Dictionary
	var posture_penalties: Dictionary = penalties.get(CANONICAL_PERK_ID, {}) as Dictionary
	_expect(posture_penalties.has("posture_correction_pct"), "legacy knockback fusion lane should migrate to Posture Correction")


func _verify_shared_runtime_value() -> void:
	_expect_close(PerkConversionValues.get_value(CANONICAL_PERK_ID, "posture_correction_pct", 1), 6.0, "Posture Correction Lv.1 value")
	_expect_close(PerkConversionValues.get_value(CANONICAL_PERK_ID, "posture_correction_pct", 5), 24.0, "Posture Correction Lv.5 value")
	var fixture: Dictionary = _make_runtime_fixture(5)
	var runtime: Object = fixture["runtime"]
	_expect_close(runtime.get_player_posture_correction_pct(), 24.0, "runtime should expose one canonical Posture Correction stat")
	_expect_close(runtime.get_player_stun_resist_pct(), 24.0, "Posture Correction should drive the stun compatibility getter")
	_expect_close(runtime.get_player_knockback_resist_pct(), 24.0, "Posture Correction should drive the knockback compatibility getter")


func _verify_round_reset_preserves_posture_projection() -> void:
	var fixture: Dictionary = _make_runtime_fixture(5)
	var movement: Object = fixture["movement"]
	movement.reset()
	_expect_close(movement.get_posture_correction_pct(), 24.0, "movement round reset should clear knockback motion without clearing persistent Posture Correction")


func _verify_stun_duration_consumption() -> void:
	var fixture: Dictionary = _make_runtime_fixture(5)
	var status: Object = fixture["status"]
	_expect_close(status.get_player_posture_correction_pct(), 24.0, "owner sync should push Posture Correction into shared status state")
	status.apply_status("player", "stun", 60.0, {}, "posture_smoke")
	_expect_close(float(status.get_status("player", "stun").get("remaining_frames", 0.0)), 45.6, "24% Posture Correction should shorten a 60-frame player stun to 45.6 frames")
	status.apply_status("boss", "stun", 60.0, {}, "boss_control")
	_expect_close(float(status.get_status("boss", "stun").get("remaining_frames", 0.0)), 60.0, "player Posture Correction must not shorten boss stun")


func _verify_knockback_distance_and_duration_consumption() -> void:
	var baseline := PlayerMovementState.new()
	var corrected := PlayerMovementState.new()
	corrected.set_posture_correction_pct(24.0)
	_expect(baseline.start_knockback(10.0, 18.0, 0.92, true, true), "baseline knockback should start")
	_expect(corrected.start_knockback(10.0, 18.0, 0.92, true, true), "corrected knockback should start")
	_expect_close(corrected.knockback_vel, 7.6, "24% Posture Correction should reduce initial knockback velocity")
	_expect_close(corrected.knockback_timer, 13.68, "24% Posture Correction should reduce knockback duration")

	var baseline_result: Dictionary = _simulate_knockback(baseline)
	var corrected_result: Dictionary = _simulate_knockback(corrected)
	_expect(float(corrected_result.get("distance", 999.0)) < float(baseline_result.get("distance", 0.0)), "higher Posture Correction should shorten knockback travel distance")
	_expect(int(corrected_result.get("frames", 999)) < int(baseline_result.get("frames", 0)), "higher Posture Correction should end knockback sooner")


func _verify_legacy_items_remain_compatible() -> void:
	var item_catalog := MythicItemCatalog.new()
	_expect(not item_catalog.build_item_by_name(CANONICAL_PERK_ID).is_empty(), "legacy Bulletproof Hat item metadata should remain")
	_expect(not item_catalog.build_item_by_name(RETIRED_PERK_ID).is_empty(), "legacy Spiked Helmet item metadata should remain")
	_expect(LanguageSettingsData.ITEM_DISPLAY_EN.has(CANONICAL_PERK_ID), "legacy Bulletproof Hat item localization should remain")
	_expect(LanguageSettingsData.ITEM_DISPLAY_EN.has(RETIRED_PERK_ID), "legacy Spiked Helmet item localization should remain")


func _make_runtime_fixture(level: int) -> Dictionary:
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels[CANONICAL_PERK_ID] = level
	var movement := PlayerMovementState.new()
	var status := StatusEffectState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": perk_state,
		"player_movement_state": movement,
		"status_effect_state": status,
	}
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	runtime.owner_syncer.sync_player_status_resistance_to_movement(runtime, registry)
	return {"runtime": runtime, "movement": movement, "status": status, "registry": registry}


func _simulate_knockback(movement: Object) -> Dictionary:
	var position := Vector2(1000.0, 0.0)
	var start_x := position.x
	var frames := 0
	while movement.get_status_snapshot().get("knockback_motion_active", false) and frames < 60:
		var result: Dictionary = movement.update_horizontal(1.0 / 60.0, position, 0.0, 0.0, -10000.0, 10000.0, 100.0)
		position = result.get("player_pos", position)
		frames += 1
	return {"distance": absf(position.x - start_x), "frames": frames}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s expected=%s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
