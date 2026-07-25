extends SceneTree

const PlazaInteriorViewData := preload("res://scripts/plaza/plaza_interior_view_data.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaInteriorViewData.new()
	var npc_texture := ImageTexture.create_from_image(Image.create(8, 12, false, Image.FORMAT_RGBA8))
	var room_texture := ImageTexture.create_from_image(Image.create(16, 9, false, Image.FORMAT_RGBA8))
	var icon_texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var snapshot := {"plaza_gold": 42, "nested": {"value": 3}}
	var player_items := [{"id": "ring", "rolls": {"power": 2}}, "skip"]
	var shop_items := [{"id": "potion"}]
	state.apply({
		"building_type": "shop",
		"title": "상점",
		"subtitle": "테스트",
		"actions": ["구매", 7],
		"last_message": "어서 오세요",
		"npc_name": "상인",
		"npc_texture": npc_texture,
		"room_texture": room_texture,
		"object_textures": {"coin_pile": icon_texture, "invalid": "path"},
		"accent_color": Color(0.2, 0.4, 0.8, 1.0),
		"save_snapshot": snapshot,
		"player_inventory": player_items,
		"shop_inventory": shop_items,
	})
	_expect(state.building_type == "shop" and state.title == "상점", "string fields")
	_expect(state.actions == ["구매", "7"], "action string normalization")
	_expect(state.npc_texture == npc_texture and state.room_backdrop_texture == room_texture, "texture fields")
	_expect(state.get_object_texture("coin_pile") == icon_texture, "object texture lookup")
	_expect(state.get_object_texture("invalid") == null, "invalid object texture filtering")
	_expect(state.get_loaded_object_texture_count() == 1, "loaded object texture count")
	_expect(state.is_topview_shop_backdrop(), "top-view shop predicate")
	(snapshot["nested"] as Dictionary)["value"] = 99
	(player_items[0]["rolls"] as Dictionary)["power"] = 99
	shop_items[0]["id"] = "mutated"
	_expect(int((state.save_snapshot.get("nested", {}) as Dictionary).get("value", 0)) == 3, "snapshot deep copy")
	_expect(int((state.player_inventory[0].get("rolls", {}) as Dictionary).get("power", 0)) == 2, "player inventory deep copy")
	_expect(str(state.shop_inventory[0].get("id", "")) == "potion", "shop inventory deep copy")
	_expect(state.player_inventory.size() == 1, "inventory should retain dictionaries only")

	state.apply({"title": "갱신", "npc_texture": "invalid", "accent_color": "invalid", "save_snapshot": "invalid"})
	_expect(state.title == "갱신" and state.building_type == "shop", "partial update retention")
	_expect(state.npc_texture == null, "invalid direct texture should clear")
	_expect(state.room_backdrop_texture == room_texture, "missing room texture should retain")
	_expect_color(state.accent, Color(0.2, 0.4, 0.8, 1.0), "invalid accent retention")
	_expect(int(state.save_snapshot.get("plaza_gold", 0)) == 42, "invalid snapshot retention")
	_expect(state.player_inventory.size() == 1 and state.shop_inventory.size() == 1, "missing inventories should retain copies")

	if _failures.is_empty():
		print("plaza_interior_view_data_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_color(actual: Color, expected: Color, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
