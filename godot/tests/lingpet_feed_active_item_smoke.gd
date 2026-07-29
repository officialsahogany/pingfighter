extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const PROTECTED_SPIRIT_WATER_ICON := "res://assets/sprites/items/lingpet_special_feed_icon.png"
const SOURCE_PATHS := [
	"res://scripts/items/active_item_catalog.gd",
	"res://scripts/plaza/plaza_gacha_transactions.gd",
	"res://scripts/plaza/plaza_shop_pricing.gd",
	"res://scripts/plaza/plaza_shop_stock.gd",
	"res://scripts/lingpet/lingpet_egg_runtime.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_retired_item_ids_are_unbuildable_and_unreferenced()
	_verify_spirit_water_placeholder_is_preserved()
	_verify_plaza_purchase_owner_refactor_is_preserved()

	if _failures.is_empty():
		print("lingpet_feed_active_item_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_retired_item_ids_are_unbuildable_and_unreferenced() -> void:
	var retired_ids := _retired_item_ids()
	var catalog := ActiveItemCatalog.new()
	for item_id in retired_ids:
		_expect(catalog.build_item_by_name(item_id).is_empty(), "retired guardian food must not build: %s" % item_id)
	for source_path in SOURCE_PATHS:
		var source := FileAccess.get_file_as_string(source_path)
		var source_without_protected_placeholder := source.replace(PROTECTED_SPIRIT_WATER_ICON, "")
		for item_id in retired_ids:
			_expect(not source_without_protected_placeholder.contains(item_id), "%s must not reference retired guardian food %s" % [source_path, item_id])
	_expect(not FileAccess.file_exists("res://scripts/lingpet/lingpet_" + "feed_controller.gd"), "retired feeding controller must be physically removed")
	_expect(not FileAccess.file_exists("res://scripts/lingpet/lingpet_" + "feed_bowl_state.gd"), "retired bowl owner must be physically removed")


func _verify_spirit_water_placeholder_is_preserved() -> void:
	var spirit_water: Dictionary = ActiveItemCatalog.new().build_item_by_name("lingpet_spirit_water")
	_expect(not spirit_water.is_empty(), "spirit water must remain buildable")
	_expect(str(spirit_water.get("icon_path", "")) == PROTECTED_SPIRIT_WATER_ICON, "spirit water must keep the approved placeholder until final art lands")
	_expect(FileAccess.file_exists(PROTECTED_SPIRIT_WATER_ICON), "protected spirit-water placeholder must remain on disk")


func _verify_plaza_purchase_owner_refactor_is_preserved() -> void:
	# This assertion retains the pre-existing plaza campaign hunk while the old
	# guardian-food assertions around it are retired.
	var shop_transactions_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_shop_transactions.gd")
	_expect(shop_transactions_source.contains("_buy_active_shop_stock_item"), "plaza active purchases should remain owned by plaza_shop_transactions")


func _retired_item_ids() -> Array[String]:
	var prefix := "lingpet_"
	var suffix := "feed"
	return [
		prefix + suffix,
		prefix + "apple_" + suffix,
		prefix + "melon_" + suffix,
		prefix + "special_" + suffix,
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
