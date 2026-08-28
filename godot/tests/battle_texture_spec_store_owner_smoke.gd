extends SceneTree

const BattleTextureSpecStore := preload(
	"res://scripts/resources/battle_texture_spec_store.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_alias_store_and_spec_contract()
	_verify_battle_resources_delegates_io_ownership()

	if _failures.is_empty():
		print("battle_texture_spec_store_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_alias_store_and_spec_contract() -> void:
	var store: Object = BattleTextureSpecStore.new()
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(64.0, 64.0)
	var spec: Dictionary = store.texture_spec(
		["player_idle_back_sheet", "player_idle_sprite_texture"],
		""
	)
	store.store_texture_spec(spec, texture)

	var cache: Dictionary = store.get_resource_cache()
	_expect(cache.get("player_idle_back_sheet", null) == texture, "the primary cache key should store the texture")
	_expect(cache.get("player_idle_sprite_texture", null) == texture, "every compatibility alias should share the same texture")
	_expect(store.is_texture_spec_loaded(spec), "all populated aliases should satisfy the loaded contract")

	cache.erase("player_idle_sprite_texture")
	_expect(not store.is_texture_spec_loaded(spec), "a missing compatibility alias should make the spec incomplete")

	var imported_spec: Dictionary = store.imported_texture_spec(["portal"], "res://portal.png", true)
	_expect(bool(imported_spec.get("prefer_imported", false)), "imported specs should preserve their loader preference")
	_expect(bool(imported_spec.get("optional", false)), "imported specs should preserve optional-resource policy")


func _verify_battle_resources_delegates_io_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/resources/battle_resources.gd")
	_expect(source.find("BattleTextureSpecStore") >= 0, "BattleResources should compose the focused texture spec store")
	_expect(
		source.find("var _resource_cache: Dictionary = {}") < 0,
		"BattleResources should not own a second backing cache dictionary"
	)
	_expect(
		source.find("ProjectResourceLoader.load_texture(") < 0
			and source.find("ProjectResourceLoader.load_imported_texture(") < 0
			and source.find("ProjectResourceLoader.get_cached_texture(") < 0,
		"BattleResources should not choose concrete texture I/O paths directly"
	)
	_expect(
		source.find("_texture_spec_store.store_texture_spec(spec, texture)") >= 0,
		"the compatibility store callback should delegate alias writes"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
