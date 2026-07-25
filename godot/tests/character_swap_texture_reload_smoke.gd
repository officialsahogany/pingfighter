extends SceneTree

# Regression seal for the F1 character-swap "paddle renders as a box" bug.
#
# Boot / stage-transition loads only the SELECTED character's player sheets into
# the shared texture cache (`include_all_characters: false`). Swapping characters
# mid-match via the F1 debug picker changed `selected_character_type` but never
# reloaded the new character's sheets, so every sprite branch in
# `stage1_player_sprite_renderer.draw()` saw a null texture and fell through to
# the `draw_fallback()` paddle box until the NEXT stage-transition reload ran.
#
# Part 1 (wiring): the real BattleSceneApi.configure_player_character must reload
#   the new character's textures and re-point owner.battle_textures (+ the three
#   skill-icon dicts). Reverse-verified: commenting out the
#   `_reload_player_character_textures(...)` call in configure_player_character
#   makes this leg FAIL (battle_textures stays the old smasher-only cache).
# Part 2 (loader): the real BattleResources.reload_player_character_textures
#   actually loads the new character's player sheet into the shared cache and
#   returns that same shared cache reference.

const BattleSceneApi := preload("res://scripts/core/battle_scene_api.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeBattleOwner:
	extends Node

	# Dictionary-backed property store so owner.set()/get() behaves like the real
	# schema-gated BattleSceneState owner (any key round-trips).
	var data: Dictionary = {
		"selected_character_id": "ufo_player",
		"selected_runtime_character_id": "smasher",
		"selected_character_type": "smasher",
		"selected_character_name": "스매셔",
		"player_speed": 5.0,
	}
	var redraw_count := 0

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		redraw_count += 1


class FakeBattleResources:
	extends RefCounted

	var call_count := 0
	var last_context: Dictionary = {}
	var cache: Dictionary = {}

	func reload_player_character_textures(context: Dictionary = {}) -> Dictionary:
		call_count += 1
		last_context = context
		var requested := str(context.get("selected_character_type", "smasher"))
		# Return a fresh cache keyed to the requested character so the wiring test
		# can prove owner.battle_textures was re-pointed to the reloaded set.
		cache = {
			"%s_player_sprite_texture" % requested: PlaceholderTexture2D.new(),
			"smasher_skill_icon_textures": {},
			"viper_skill_icon_textures": {"air_blade": PlaceholderTexture2D.new()},
			"commando_skill_icon_textures": {},
		}
		return cache


class FakeRegistry:
	extends RefCounted

	var character_runtime: Object = PlayerCharacterRuntime.new()
	var resources: Object = FakeBattleResources.new()

	func get_instance(key: String) -> Object:
		match key:
			"player_character_runtime":
				return character_runtime
			"battle_resources":
				return resources
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_swap_reloads_and_repoints_owner_textures()
	_verify_real_loader_loads_new_character_sheet()
	_cleanup_runtime_resources()

	if _failures.is_empty():
		print("character_swap_texture_reload_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_swap_reloads_and_repoints_owner_textures() -> void:
	var owner := FakeBattleOwner.new()
	get_root().add_child(owner)
	# Simulate the boot state: only the initially selected character (smasher)
	# is present in the cache. Viper's sheet key is absent -> would box.
	var boot_cache := {"player_sprite_texture": PlaceholderTexture2D.new()}
	owner.data["battle_textures"] = boot_cache
	owner.data["viper_skill_icon_textures"] = {}

	var registry := FakeRegistry.new()
	var api := BattleSceneApi.new()
	api.configure_player_character(owner, registry, "viper")

	var fake_resources: Object = registry.resources
	_expect(int(fake_resources.call_count) == 1, "character swap should reload player textures exactly once")
	_expect(str(fake_resources.last_context.get("selected_character_type", "")) == "viper", "reload should request the NEW character's textures")
	_expect(bool(fake_resources.last_context.get("include_result_sheets", false)), "swap reload should include result sheets so a later win/lose shows the new character")

	var repointed: Variant = owner.data.get("battle_textures", null)
	_expect(repointed is Dictionary, "battle_textures should stay a dictionary after swap")
	if repointed is Dictionary:
		var repointed_dict: Dictionary = repointed
		_expect(repointed_dict.get("viper_player_sprite_texture", null) is Texture2D, "after swapping to Viper, battle_textures should contain the Viper sprite sheet (not fall back to the box)")
		_expect(not repointed_dict.has("player_sprite_texture"), "battle_textures should be re-pointed to the reloaded cache, not the stale smasher-only boot cache")
	_expect(repointed != boot_cache, "swap must replace the stale boot texture cache reference")

	var viper_icons: Variant = owner.data.get("viper_skill_icon_textures", null)
	_expect(viper_icons is Dictionary and (viper_icons as Dictionary).has("air_blade"), "swap should also re-point the character skill-icon dicts so HUD orb icons match the new character")

	owner.queue_free()


func _verify_real_loader_loads_new_character_sheet() -> void:
	var resources: Object = BattleResources.new()
	# Boot-equivalent: load only smasher.
	var smasher_cache: Variant = resources.reload_player_character_textures({
		"selected_character_type": "smasher",
		"include_result_sheets": true,
	})
	_expect(smasher_cache is Dictionary, "reload should return the shared resource cache dictionary")
	if smasher_cache is Dictionary:
		_expect(_has_texture(smasher_cache, "player_sprite_texture"), "smasher reload should load the smasher walk sheet")
		_expect(not _has_texture(smasher_cache, "viper_player_sprite_texture"), "before swapping, the Viper sheet should NOT be loaded (this is why an un-reloaded swap boxes)")

	# Swap to viper: the new character's sheet must now be present.
	var viper_cache: Variant = resources.reload_player_character_textures({
		"selected_character_type": "viper",
		"include_result_sheets": true,
	})
	if viper_cache is Dictionary:
		_expect(_has_texture(viper_cache, "viper_player_sprite_texture"), "swapping to Viper must load the Viper sprite sheet into the cache")
		var viper_icons: Variant = viper_cache.get("viper_skill_icon_textures", null)
		_expect(viper_icons is Dictionary and not (viper_icons as Dictionary).is_empty(), "swapping to Viper should populate the Viper skill-icon map")
	_expect(viper_cache == smasher_cache, "reload should return the SAME shared cache reference (owner.battle_textures aliases it)")


func _has_texture(cache: Dictionary, key: String) -> bool:
	return cache.get(key, null) is Texture2D


func _cleanup_runtime_resources() -> void:
	ProjectResourceLoader.clear_caches()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
