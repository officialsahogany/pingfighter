extends SceneTree

const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")

var _failures: Array[String] = []


func _init() -> void:
	var catalog := PerkFusionByproductCatalog.new()
	var full_pool: Array[String] = catalog.get_contextual_pool([], ["item_luck"], true)
	_expect(full_pool.size() == 14, "live contextual pool should contain all fourteen wired byproducts")
	_expect("meridian_expand" in full_pool, "flag ON should expose meridian expansion in the general pool")
	_expect("sleeve_cosmos" not in full_pool, "retired Sleevebound Cosmos must never enter the roll pool")
	_expect("limit_break" in full_pool, "limit break should appear with an eligible source")
	_expect("linked_arsenal" in full_pool, "rare pool should expose Linked Arsenal")
	_expect("returning_light_step" in full_pool, "rare pool should expose Last-Light Phantom Step")
	_expect("spellbreaker_guard" in full_pool, "rare pool should expose Spellbreaking Guard Art")
	_expect("gravitybelt" in full_pool and "smartphone" in full_pool, "promoted Mugong should live in the Superior Martial Art pool")
	for reserved_id: String in PerkFusionByproductCatalog.RESERVED_IDS:
		_expect(reserved_id not in full_pool, "reserved v1.5 id %s must never enter the v1 roll pool" % reserved_id)
		_expect(not catalog.is_runtime_enabled(reserved_id), "reserved v1.5 id %s must remain runtime-disabled" % reserved_id)
	for retired_id: String in PerkFusionByproductCatalog.RETIRED_IDS:
		_expect(retired_id not in full_pool, "retired id %s must never re-enter the roll pool" % retired_id)
		_expect(not catalog.is_runtime_enabled(retired_id), "retired id %s must stay runtime-disabled" % retired_id)

	var contextual: Array[String] = catalog.get_contextual_pool(["reverb", "dual_catalyst"], [], true)
	_expect("reverb" not in contextual and "dual_catalyst" not in contextual, "owned byproducts should be excluded globally")
	_expect("limit_break" not in contextual, "limit break should be excluded without an eligible source")
	_expect(contextual.size() == 11, "two owned ids plus contextual limit-break exclusion should leave eleven choices")
	var after_meridian: Array[String] = catalog.get_contextual_pool(["meridian_expand"], ["item_luck"], true)
	_expect("meridian_expand" not in after_meridian, "owned meridian expansion should be excluded from later rolls")
	var legacy_pool: Array[String] = catalog.get_contextual_pool([], ["item_luck"], false)
	_expect("meridian_expand" not in legacy_pool, "flag OFF must exclude the inert meridian expansion reward")
	_expect(legacy_pool.size() == 13, "flag OFF should exclude only the inert meridian expansion reward")
	var thunder_drive: Dictionary = catalog.get_data("overload_circuit")
	_expect(str(thunder_drive.get("name", "")) == "벽력추진", "catalog should expose the renamed Thunderbolt Drive art")
	_expect(str(thunder_drive.get("detail", "")).contains("15%") and str(thunder_drive.get("detail", "")).contains("80%") and str(thunder_drive.get("detail", "")).contains("붉은보라색") and str(thunder_drive.get("detail", "")).contains("보스"), "Thunderbolt Drive copy should expose trigger chance, speed boost, ball color, and boss-guard reset")
	_expect(str(PerkFusionLocalization.BYPRODUCT_EN.get("overload_circuit", "")) == "Thunderbolt Drive", "English fusion copy should expose the renamed art")
	_expect(str(PerkFusionLocalization.BYPRODUCT_DETAIL_EN.get("overload_circuit", "")).contains("15%") and str(PerkFusionLocalization.BYPRODUCT_DETAIL_EN.get("overload_circuit", "")).contains("80%") and str(PerkFusionLocalization.BYPRODUCT_DETAIL_EN.get("overload_circuit", "")).contains("red-purple"), "English fusion copy should expose the exact trigger, speed, and color values")
	var desperate_rebirth: Dictionary = catalog.get_data("recycle_protocol")
	_expect(str(desperate_rebirth.get("name", "")) == "절처봉생", "catalog should expose the 환격전-style recycle byproduct name")
	_expect(str(PerkFusionLocalization.BYPRODUCT_EN.get("recycle_protocol", "")) == "Rebirth at the Brink", "English fusion copy should expose the renamed recycle byproduct")
	_expect(str(PerkFusionLocalization.BYPRODUCT_EN.get("gravitybelt", "")) == "Instant Shadow Art", "English fusion copy should retain the promoted 찰나신법 name")
	_expect(str(PerkFusionLocalization.BYPRODUCT_EN.get("smartphone", "")) == "Adaptive Art", "English fusion copy should retain the promoted 응변결 name")
	for locale: String in ["zh", "ja", "es", "pt-BR", "ru"]:
		var names: Dictionary = PerkFusionLocalization.BYPRODUCT_LOCALIZED.get(locale, {}) as Dictionary
		var details: Dictionary = PerkFusionLocalization.BYPRODUCT_DETAIL_LOCALIZED.get(locale, {}) as Dictionary
		_expect(not str(names.get("overload_circuit", "")).is_empty(), "%s should localize the renamed Thunderbolt Drive art" % locale)
		_expect(str(details.get("overload_circuit", "")).contains("15%") and str(details.get("overload_circuit", "")).contains("80%"), "%s should localize the exact Thunderbolt Drive values" % locale)
		_expect(not str(names.get("recycle_protocol", "")).is_empty(), "%s should localize Rebirth at the Brink" % locale)
		for promoted_id: String in ["gravitybelt", "smartphone"]:
			_expect(not str(names.get(promoted_id, "")).is_empty(), "%s should localize promoted byproduct %s" % [locale, promoted_id])
			_expect(not str(details.get(promoted_id, "")).is_empty(), "%s should localize promoted byproduct detail %s" % [locale, promoted_id])
		_expect(not str(names.get("returning_light_step", "")).is_empty(), "%s should localize Last-Light Phantom Step" % locale)
		_expect(str(details.get("returning_light_step", "")).contains("30%"), "%s should localize the exact emergency blink chance" % locale)
		_expect(not str(names.get("spellbreaker_guard", "")).is_empty(), "%s should localize Spellbreaking Guard Art" % locale)
		_expect(str(details.get("spellbreaker_guard", "")).contains("12%") and str(details.get("spellbreaker_guard", "")).contains("5"), "%s should localize the exact ward chance and duration" % locale)
	_expect(str(catalog.get_data("static_field").get("name", "")) == "정전기장", "catalog should expose Korean display data")
	_expect(str(catalog.get_data("meridian_expand").get("name", "")) == "기맥 확장", "catalog should expose the approved Korean meridian expansion name")
	_expect(str(catalog.get_data("meridian_expand").get("rarity", "")) == "general", "meridian expansion must stay in the general pool")
	_expect(str(catalog.get_data("sleeve_cosmos").get("name", "")) == "수리건곤", "retired Sleevebound Cosmos should keep its Korean name for legacy-record healing context")
	_expect(str(catalog.get_data("sleeve_cosmos").get("rarity", "")) == "retired", "Sleevebound Cosmos must stay retired")
	_expect(str(catalog.get_data("linked_arsenal").get("name", "")) == "연환병장", "catalog should expose the new rare slot-art name")
	_expect(str(catalog.get_data("linked_arsenal").get("rarity", "")) == "rare", "Linked Arsenal must stay in the rare pool")
	var returning_light_step: Dictionary = catalog.get_data("returning_light_step")
	_expect(str(returning_light_step.get("name", "")) == "회광환보", "catalog should expose the approved emergency blink name")
	_expect(str(returning_light_step.get("rarity", "")) == "rare", "Last-Light Phantom Step must stay in the rare pool")
	_expect(str(returning_light_step.get("detail", "")).contains("30%") and str(returning_light_step.get("detail", "")).contains("활주 토큰"), "catalog should expose the exact emergency trigger contract")
	_expect(str(PerkFusionLocalization.BYPRODUCT_EN.get("returning_light_step", "")) == "Last-Light Phantom Step", "English fusion copy should expose the new rare art")
	var spellbreaker_guard: Dictionary = catalog.get_data("spellbreaker_guard")
	_expect(str(spellbreaker_guard.get("name", "")) == "파법호신결", "catalog should expose the approved spell-parry art name")
	_expect(str(spellbreaker_guard.get("rarity", "")) == "rare", "Spellbreaking Guard Art must stay in the rare pool")
	_expect(str(spellbreaker_guard.get("detail", "")).contains("12%") and str(spellbreaker_guard.get("detail", "")).contains("5초"), "catalog should expose the exact ward chance and duration")
	_expect(str(catalog.get_data("gravitybelt").get("name", "")) == "찰나신법", "Instant Shadow Art should be promoted without renaming")
	_expect(str(catalog.get_data("gravitybelt").get("rarity", "")) == "general", "Instant Shadow Art should enter the general byproduct pool")
	_expect(str(catalog.get_data("smartphone").get("name", "")) == "응변결", "Adaptive Art should be promoted without renaming")
	_expect(str(catalog.get_data("smartphone").get("rarity", "")) == "general", "Adaptive Art should enter the general byproduct pool")

	if _failures.is_empty():
		print("perk_fusion_byproduct_catalog_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
