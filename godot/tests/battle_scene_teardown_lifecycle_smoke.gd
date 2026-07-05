extends SceneTree

const BattleSceneStartupController := preload("res://scripts/core/battle_scene_startup_controller.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const CharacterSelectPrewarm := preload("res://scripts/ui/character_select_prewarm.gd")

var _failures: Array[String] = []
var _fake_modules: Dictionary = {}
var _clear_module_cache_calls := 0


class FakeLogoIntro:
	extends RefCounted

	var cleanup_calls := 0

	func cleanup() -> void:
		cleanup_calls += 1


class FakeAudio:
	extends RefCounted

	var stop_bgm_calls := 0

	func stop_bgm() -> void:
		stop_bgm_calls += 1


class FakeRegistry:
	extends RefCounted

	var clear_all_calls := 0

	func clear_all() -> void:
		clear_all_calls += 1


class FakeTeardownLifecycle:
	extends RefCounted

	var calls := 0

	func exit_tree(_owner: Node, _registry: Object, _cached_module_getter: Callable, _callbacks: Dictionary) -> void:
		calls += 1


func _init() -> void:
	_verify_teardown_lifecycle_cleans_runtime_surfaces()
	_verify_teardown_retains_character_select_warm_set()
	_verify_startup_controller_delegates_exit_tree_surface()

	if _failures.is_empty():
		print("battle_scene_teardown_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_teardown_lifecycle_cleans_runtime_surfaces() -> void:
	var lifecycle: Object = BattleSceneTeardownLifecycle.new()
	var logo := FakeLogoIntro.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	var owner := Node.new()
	_fake_modules = {
		"penguin_logo_intro": logo,
		"game_audio": audio,
	}
	_clear_module_cache_calls = 0

	lifecycle.exit_tree(owner, registry, Callable(self, "_get_fake_module"), {
		"clear_module_cache": Callable(self, "_on_clear_module_cache"),
	})

	_expect(logo.cleanup_calls == 1, "teardown lifecycle should cleanup logo intro")
	_expect(audio.stop_bgm_calls == 1, "teardown lifecycle should stop battle BGM")
	_expect(registry.clear_all_calls == 1, "teardown lifecycle should clear the gameplay registry")
	_expect(_clear_module_cache_calls == 1, "teardown lifecycle should call clear-module-cache callback")
	owner.free()


func _verify_teardown_retains_character_select_warm_set() -> void:
	# Post-battle exits (F10 booth reset, true-defeat settlement, stage-clear
	# exit) skip the boot loading screen, so teardown must not wipe the
	# character-select warm set out of the ProjectResourceLoader caches.
	var retained: Dictionary = CharacterSelectPrewarm.new().collect_retained_cache_paths()
	var warm_texture_paths: Array = retained.get("textures", [])
	_expect(
		not warm_texture_paths.is_empty(),
		"character-select warm set should list at least one texture path"
	)
	if warm_texture_paths.is_empty():
		return
	var warm_path := str(warm_texture_paths[0])
	var warm_texture := PlaceholderTexture2D.new()
	var battle_path := "res://tests/fake_battle_texture_for_teardown_smoke.png"
	var battle_texture := PlaceholderTexture2D.new()
	ProjectResourceLoader.clear_caches()
	ProjectResourceLoader.store_texture(warm_path, warm_texture)
	ProjectResourceLoader.store_texture(battle_path, battle_texture)

	var lifecycle: Object = BattleSceneTeardownLifecycle.new()
	var owner := Node.new()
	_fake_modules = {}
	lifecycle.exit_tree(owner, FakeRegistry.new(), Callable(self, "_get_fake_module"), {})
	owner.free()

	_expect(
		ProjectResourceLoader.get_cached_texture(warm_path) == warm_texture,
		"battle teardown must retain the character-select warm set in the texture cache (post-battle exits skip the boot loading screen)"
	)
	_expect(
		ProjectResourceLoader.get_cached_texture(battle_path) == null,
		"battle teardown should still clear textures outside the character-select warm set"
	)
	ProjectResourceLoader.clear_caches()


func _verify_startup_controller_delegates_exit_tree_surface() -> void:
	var startup: Object = BattleSceneStartupController.new()
	var fake := FakeTeardownLifecycle.new()
	var owner := Node.new()
	startup.teardown_lifecycle = fake

	startup.exit_tree(owner, FakeRegistry.new(), Callable(self, "_get_fake_module"), {})

	_expect(fake.calls == 1, "startup controller should delegate exit_tree to teardown lifecycle")
	owner.free()


func _get_fake_module(key: String) -> Object:
	var value: Variant = _fake_modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _on_clear_module_cache() -> void:
	_clear_module_cache_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
