extends SceneTree

const BattleSceneBootstrap := preload("res://scripts/core/battle_scene_bootstrap.gd")

var _failures: Array[String] = []


class FakeBattleResources:
	extends RefCounted

	var load_all_calls := 0
	var last_context: Dictionary = {}
	var cache: Dictionary = {}

	func get_resource_cache() -> Dictionary:
		return cache

	func load_all(context: Dictionary) -> Dictionary:
		load_all_calls += 1
		last_context = context.duplicate(true)
		cache = _complete_cache(bool(context.get("include_result_sheets", true)))
		return cache

	func _complete_cache(include_result_sheets: bool = true) -> Dictionary:
		var result := {
			"player_sprite_texture": GradientTexture1D.new(),
			"smasher_skill_icon_textures": {},
			"viper_skill_icon_textures": {},
			"commando_skill_icon_textures": {},
		}
		if include_result_sheets:
			result["player_victory_sheet"] = GradientTexture1D.new()
			result["player_defeat_sheet"] = GradientTexture1D.new()
			result["boss_victory_sheet"] = GradientTexture1D.new()
			result["boss_defeat_sheet"] = GradientTexture1D.new()
		return result


class FakeRegistry:
	extends RefCounted

	var battle_resources := FakeBattleResources.new()

	func get_instance(key: String) -> Object:
		if key == "battle_resources":
			return battle_resources
		return null


func _init() -> void:
	_verify_partial_cache_is_used_without_result_reload()
	_verify_empty_cache_loads_runtime_textures_without_result_sheets()
	_verify_complete_cache_is_used_as_is()

	if _failures.is_empty():
		print("battle_scene_bootstrap_result_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_partial_cache_is_used_without_result_reload() -> void:
	var registry := FakeRegistry.new()
	registry.battle_resources.cache = {
		"player_sprite_texture": GradientTexture1D.new(),
		"smasher_skill_icon_textures": {},
		"viper_skill_icon_textures": {},
		"commando_skill_icon_textures": {},
	}
	var owner := Node.new()
	var snapshot: Dictionary = BattleSceneBootstrap.new().initialize(owner, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"play_stage_bgm_on_initialize": false,
	}, registry)
	owner.free()

	_expect(registry.battle_resources.load_all_calls == 0, "bootstrap should not reload cached battle textures only because result sheets are absent")
	_expect(snapshot.get("battle_textures", {}) == registry.battle_resources.cache, "bootstrap should use the cached battle texture dictionary as-is")


func _verify_empty_cache_loads_runtime_textures_without_result_sheets() -> void:
	var registry := FakeRegistry.new()
	var owner := Node.new()
	var snapshot: Dictionary = BattleSceneBootstrap.new().initialize(owner, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"play_stage_bgm_on_initialize": false,
	}, registry)
	owner.free()

	_expect(registry.battle_resources.load_all_calls == 1, "bootstrap should still load battle textures when no cache exists")
	_expect(not bool(registry.battle_resources.last_context.get("include_result_sheets", true)), "bootstrap fallback should defer result sheets to the result prewarm path")
	_expect(snapshot.get("battle_textures", {}).get("player_sprite_texture", null) is Texture2D, "bootstrap fallback should include runtime player textures")
	_expect(not snapshot.get("battle_textures", {}).has("player_victory_sheet"), "bootstrap fallback should not load player result sheets")
	_expect(not snapshot.get("battle_textures", {}).has("boss_defeat_sheet"), "bootstrap fallback should not load boss result sheets")


func _verify_complete_cache_is_used_as_is() -> void:
	var registry := FakeRegistry.new()
	registry.battle_resources.cache = registry.battle_resources._complete_cache()
	var owner := Node.new()
	var snapshot: Dictionary = BattleSceneBootstrap.new().initialize(owner, {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"play_stage_bgm_on_initialize": false,
	}, registry)
	owner.free()

	_expect(registry.battle_resources.load_all_calls == 0, "bootstrap should keep a cache that already has round-result sheets")
	_expect(snapshot.get("battle_textures", {}) == registry.battle_resources.cache, "bootstrap should return the complete cached battle texture dictionary")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
