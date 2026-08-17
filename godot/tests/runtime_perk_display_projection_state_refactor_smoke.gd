extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDisplayProjectionState := preload("res://scripts/characters/runtime_perk_display_projection_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeScarFusionState:
	extends RefCounted

	func get_all_records() -> Array:
		return [{
			"sources": ["chargebag"],
			"option_penalties": {"chargebag": {"chargebag_pct": 0.20}},
			"commit_value_snapshots": {},
			"deleted_options": {},
		}]


class FakePolishScarRuntime:
	extends RefCounted

	var fusion_state := FakeScarFusionState.new()

	func get_perk_fusion_state() -> Object:
		return fusion_state

	func get_runtime_skill_level(perk_id: String) -> int:
		return 5 if perk_id == "chargebag" else 0

	func get_perk_amplify_multiplier(_perk_id: String) -> float:
		return 1.10

	func apply_perk_fusion_option_value(
		_perk_id: String,
		_option_key: String,
		base_value: float
	) -> float:
		return base_value * 0.80


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_owner_boundary()
	_verify_direct_cache_and_runtime_facade()
	_verify_polished_fusion_scar_projection()
	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("runtime_perk_display_projection_state_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_polished_fusion_scar_projection() -> void:
	var owner := RuntimePerkDisplayProjectionState.new()
	var live: Dictionary = owner._build_live_source_options(FakePolishScarRuntime.new())
	var chargebag: Dictionary = live.get("chargebag", {})
	var lane: Dictionary = chargebag.get("chargebag_pct", {})
	_expect_close(float(lane.get("value", 0.0)), 60.5, "fusion hover should show the polished pre-scar value")
	_expect_close(float(lane.get("adjusted_value", 0.0)), 48.4, "fusion hover should show the canonical polished live value after the scar")


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_display_projection_state.gd")
	_expect(RuntimePerkDisplayProjectionState != null, "display-projection state owner should preload")
	_expect(
		runtime_source.find("RuntimePerkDisplayProjectionState") >= 0
		and runtime_source.find("_display_projection_state.get_composite_projection(") >= 0,
		"runtime perk facade should delegate composite display projection"
	)
	_expect(
		owner_source.find("func get_composite_projection(") >= 0
		and owner_source.find("func build_mystic_dice_projection(") >= 0
		and owner_source.find("func _build_live_source_options(") >= 0
		and owner_source.find("func merge_perk_fusion_modal_preview(") >= 0
		and owner_source.find("func reset_modal_preview_cache(") >= 0
		and owner_source.find("func _matches_projection_signature(") >= 0
		and owner_source.find("func invalidate(") >= 0,
		"display owner should own composite build, scalar cache signature, live option projection, dedicated Dice build, and invalidation"
	)
	var cache_hit_check := owner_source.find("if _matches_projection_signature(")
	var public_hash_build := owner_source.find("var cache_key := hash([")
	_expect(
		cache_hit_check >= 0 and public_hash_build > cache_hit_check,
		"cache-hit path should compare scalar signature fields before allocating the public hash Array"
	)
	_expect(
		runtime_source.find("func _build_perk_fusion_live_source_options(") < 0,
		"runtime perk facade should not retain display-only live option projection"
	)
	for removed_field in [
		"var _perk_fusion_display_projector:",
		"var _perk_fusion_display_catalog:",
		"var _perk_fusion_projection_cache:",
		"var _perk_fusion_projection_cache_key",
		"var _perk_fusion_projection_cache_ready",
		"var _perk_fusion_projection_builds",
		"var _mystic_dice_display_projector:",
		"var _perk_fusion_modal_preview_cache:",
		"var _perk_fusion_modal_preview_cache_key",
		"var _perk_fusion_modal_preview_builds",
	]:
		_expect(runtime_source.find(removed_field) < 0, "runtime should not retain display cache field %s" % removed_field)


func _verify_direct_cache_and_runtime_facade() -> void:
	var runtime := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	runtime.runtime_skill_levels = {"dash_amplification": 2}
	var owner := RuntimePerkDisplayProjectionState.new()
	var first: Dictionary = owner.get_composite_projection(runtime, catalog)
	var repeated: Dictionary = owner.get_composite_projection(runtime, catalog)
	_expect(first == repeated, "unchanged display inputs should reuse the cached projection value")
	_expect(int(owner.get_cache_stats().get("projection_builds", 0)) == 1, "direct display owner should build once for repeated reads")
	runtime.runtime_skill_levels["dash_amplification"] = 3
	var changed: Dictionary = owner.get_composite_projection(runtime, catalog)
	_expect(changed.get("cache_signature") != first.get("cache_signature"), "runtime level hash should invalidate the direct display cache")
	_expect(int(owner.get_cache_stats().get("projection_builds", 0)) == 2, "level mutation should rebuild exactly once")
	owner.invalidate()
	owner.get_composite_projection(runtime, catalog)
	_expect(int(owner.get_cache_stats().get("projection_builds", 0)) == 3, "explicit invalidation should rebuild on the next read")
	_expect(
		(owner.build_mystic_dice_projection(runtime.get_mystic_dice_snapshot()).get("entries", []) as Array).is_empty(),
		"dedicated Dice projection should stay empty before the first committed roll"
	)
	var modal_snapshot := {"selected_source_ids": [], "phase": "materials"}
	var first_preview: Dictionary = owner.merge_perk_fusion_modal_preview(runtime, modal_snapshot.duplicate(true), catalog)
	owner.merge_perk_fusion_modal_preview(runtime, modal_snapshot.duplicate(true), catalog)
	_expect(first_preview.has("outcome_preview") and first_preview.has("source_previews"), "modal preview owner should merge production preview fields")
	_expect(int(owner.get_cache_stats().get("modal_preview_builds", 0)) == 1, "unchanged modal snapshots should hit the preview cache")
	modal_snapshot["phase"] = "animation"
	owner.merge_perk_fusion_modal_preview(runtime, modal_snapshot.duplicate(true), catalog)
	_expect(int(owner.get_cache_stats().get("modal_preview_builds", 0)) == 2, "modal phase changes should rebuild the preview once")
	owner.reset_modal_preview_cache()
	owner.merge_perk_fusion_modal_preview(runtime, modal_snapshot.duplicate(true), catalog)
	_expect(int(owner.get_cache_stats().get("modal_preview_builds", 0)) == 3, "modal boundary reset should force one fresh preview build")

	var facade_first: Dictionary = runtime.get_perk_fusion_display_projection(catalog)
	var facade_builds := int(runtime.get_perk_fusion_display_cache_stats().get("projection_builds", 0))
	runtime.get_perk_fusion_display_projection(catalog)
	_expect(int(runtime.get_perk_fusion_display_cache_stats().get("projection_builds", 0)) == facade_builds, "runtime facade should retain cache hits")
	runtime.reset()
	var facade_after_reset: Dictionary = runtime.get_perk_fusion_display_projection(catalog)
	_expect(facade_after_reset.has("cache_signature"), "post-reset projection should keep the public cache signature")
	_expect(facade_after_reset.get("cache_signature") != facade_first.get("cache_signature"), "reset-cleared runtime levels should produce a fresh signature")
	_expect(int(runtime.get_perk_fusion_display_cache_stats().get("projection_builds", 0)) == facade_builds + 1, "runtime reset should invalidate the delegated cache exactly once")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])
