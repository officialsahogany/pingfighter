extends SceneTree

const PlazaInteriorObjectRenderer := preload("res://scripts/plaza/plaza_interior_object_renderer.gd")
const PlazaShopClickFxRenderer := preload("res://scripts/plaza/plaza_shop_click_fx_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_expect(PlazaInteriorObjectRenderer.get_object_texture_draw_size("capsule") == Vector2(74.0, 96.0), "capsule texture size should retain the live visual contract")
	_expect(PlazaInteriorObjectRenderer.get_object_texture_draw_size("sell") == Vector2(92.0, 88.0), "sell texture size should retain the live visual contract")
	_expect(PlazaInteriorObjectRenderer.get_object_texture_draw_size("crystal") == Vector2(72.0, 98.0), "default texture size should retain the live visual contract")
	_expect(PlazaInteriorObjectRenderer.get_object_texture_center_offset("sell") == Vector2(0.0, -2.0), "sell texture should retain its center offset")
	_expect(PlazaInteriorObjectRenderer.get_object_texture_center_offset("capsule") == Vector2(0.0, -4.0), "default texture should retain its center offset")
	_expect(PlazaShopClickFxRenderer.get_texture_key({"kind": "coin_pile"}) == "coin_pile_anim", "coin click FX should resolve the animated sheet key")
	_expect(PlazaShopClickFxRenderer.get_texture_key({"kind": "gear"}) == "", "non-animated click FX should not invent a texture key")
	if _failures.is_empty():
		print("plaza_interior_object_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
