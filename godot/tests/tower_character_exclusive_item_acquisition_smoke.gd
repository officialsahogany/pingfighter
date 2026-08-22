extends SceneTree

const ActiveItemCatalog := preload(
	"res://scripts/items/active_item_catalog.gd"
)
const MythicItemCatalog := preload(
	"res://scripts/items/mythic_item_catalog.gd"
)
const StageClearRewardResolver := preload(
	"res://scripts/core/stage_clear_reward_resolver.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentShopInventory := preload(
	"res://scripts/tower_ascent/tower_ascent_shop_inventory.gd"
)

const EXPECTED_CHARACTER_EXCLUSIVE_ITEMS := {
	"ammo_box": "soldier",
	"doping_potion": "soldier",
	"venom_mist_gauntlet": "viper",
}
const HORAN_SHOP_OPEN_COUNT := 256
const HAN_MIRYANG_SHOP_OPEN_COUNT := 256

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 4
	var active_item_slots: Array = []


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeRegistry:
	extends RefCounted

	var unlock_store := FakeUnlockStore.new()

	func get_instance(key: String) -> Variant:
		if key == "tower_ascent_unlock_store":
			return unlock_store
		return null

	func get_cached_instance(_key: String) -> Variant:
		return null


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_character_exclusive_catalog_inventory()
	_verify_shop_open_character_gate()
	_verify_normal_chest_candidate_gate()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_character_exclusive_item_acquisition_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_character_exclusive_catalog_inventory() -> void:
	var found: Dictionary = {}
	var active_catalog := ActiveItemCatalog.new()
	for item_name_value in ActiveItemCatalog.CATALOG_ORDER:
		var item_name := str(item_name_value)
		var item_data: Dictionary = active_catalog.build_item_by_name(item_name)
		var restriction := str(item_data.get("character_restriction", "")).strip_edges()
		if not restriction.is_empty():
			found[item_name] = restriction
	var mythic_catalog := MythicItemCatalog.new()
	for item_name_value in MythicItemCatalog.FIELD_SPAWN_ORDER:
		var item_name := str(item_name_value)
		var item_data: Dictionary = mythic_catalog.build_item_by_name(item_name)
		var restriction := str(item_data.get("character_restriction", "")).strip_edges()
		if not restriction.is_empty():
			found[item_name] = restriction
	_expect(
		found == EXPECTED_CHARACTER_EXCLUSIVE_ITEMS,
		"all character-exclusive item metadata must stay inventoried: %s" % [found]
	)


func _verify_shop_open_character_gate() -> void:
	var registry := FakeRegistry.new()
	var inventory_builder := TowerAscentShopInventory.new()
	var han_miryang := FakeOwner.new()
	var han_restricted_stock: Array[String] = []
	for open_index in range(HAN_MIRYANG_SHOP_OPEN_COUNT):
		var inventory: Dictionary = inventory_builder.build_inventory(
			"han_shop_%d" % open_index,
			11000 + open_index,
			han_miryang,
			registry
		)
		_expect(bool(inventory.get("accepted", false)), "Han Miryang shop must generate")
		han_restricted_stock.append_array(_restricted_stock_names(inventory))
	_expect(
		han_restricted_stock.is_empty(),
		"Han Miryang must see zero character-exclusive stock across repeated shop opens: %s" % [han_restricted_stock]
	)

	var horan := FakeOwner.new()
	horan.selected_character_type = "soldier"
	var horan_seen: Dictionary = {}
	for open_index in range(HORAN_SHOP_OPEN_COUNT):
		var inventory: Dictionary = inventory_builder.build_inventory(
			"horan_shop_%d" % open_index,
			22000 + open_index,
			horan,
			registry
		)
		_expect(bool(inventory.get("accepted", false)), "Horan shop must generate")
		for item_name in _restricted_stock_names(inventory):
			horan_seen[item_name] = true
	_expect(horan_seen.has("ammo_box"), "Horan repeated shop opens must reach ammo_box")
	_expect(horan_seen.has("doping_potion"), "Horan repeated shop opens must reach doping_potion")


func _verify_normal_chest_candidate_gate() -> void:
	var registry := FakeRegistry.new()
	var resolver := StageClearRewardResolver.new()
	var han_miryang := FakeOwner.new()
	var han_candidates: Array = resolver._build_candidates_for_group(
		StageClearRewardResolver.REWARD_ACTIVE,
		han_miryang,
		registry
	)
	_expect(
		_restricted_candidate_names(han_candidates).is_empty(),
		"Han Miryang normal-chest reward candidates must exclude character-exclusive items"
	)
	var horan := FakeOwner.new()
	horan.selected_character_type = "soldier"
	var horan_candidates: Array = resolver._build_candidates_for_group(
		StageClearRewardResolver.REWARD_ACTIVE,
		horan,
		registry
	)
	var horan_names := _restricted_candidate_names(horan_candidates)
	_expect(horan_names.has("ammo_box"), "Horan normal-chest candidates must retain ammo_box")
	_expect(horan_names.has("doping_potion"), "Horan normal-chest candidates must retain doping_potion")


func _restricted_stock_names(inventory: Dictionary) -> Array[String]:
	return _restricted_candidate_names(inventory.get("stock", []))


func _restricted_candidate_names(candidates: Array) -> Array[String]:
	var result: Array[String] = []
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var item_name := str((candidate_value as Dictionary).get("item_name", (candidate_value as Dictionary).get("name", "")))
		if EXPECTED_CHARACTER_EXCLUSIVE_ITEMS.has(item_name):
			result.append(item_name)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
