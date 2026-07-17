extends SceneTree

const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	var catalog := PerkFusionByproductCatalog.new()
	var full_pool: Array[String] = catalog.get_contextual_pool([], ["item_luck"])
	_expect(full_pool.size() == 8, "v1 contextual pool should contain exactly eight wired byproducts")
	_expect("limit_break" in full_pool, "limit break should appear with an eligible source")
	for reserved_id: String in PerkFusionByproductCatalog.RESERVED_IDS:
		_expect(reserved_id not in full_pool, "reserved v1.5 id %s must never enter the v1 roll pool" % reserved_id)
		_expect(not catalog.is_runtime_enabled(reserved_id), "reserved v1.5 id %s must remain runtime-disabled" % reserved_id)

	var contextual: Array[String] = catalog.get_contextual_pool(["reverb", "dual_catalyst"], [])
	_expect("reverb" not in contextual and "dual_catalyst" not in contextual, "owned byproducts should be excluded globally")
	_expect("limit_break" not in contextual, "limit break should be excluded without an eligible source")
	_expect(contextual.size() == 5, "two owned ids plus contextual limit-break exclusion should leave five choices")
	_expect(str(catalog.get_data("static_field").get("name", "")) == "정전기장", "catalog should expose Korean display data")

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
