extends SceneTree

const StageClearResultRewardIconResolver := preload("res://scripts/ui/stage_clear_result_reward_icon_resolver.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

const SPEEDBOOTS_ICON_PATH := "res://assets/sprites/items/speedboots.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_icon_path_resolution()
	_verify_texture_resolution()
	_verify_scene_delegates_icon_resolver()

	if _failures.is_empty():
		print("stage_clear_result_reward_icon_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_icon_path_resolution() -> void:
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_path({"icon_path": "res://direct.png", "item_data": {"icon_path": "res://nested.png"}}) == "res://direct.png",
		"direct reward icon_path should win over item_data icon_path"
	)
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_path({"item_data": {"icon_path": "res://nested.png"}}) == "res://nested.png",
		"item_data icon_path should be used when direct icon_path is absent"
	)
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_path({"item_name": "speedboots"}) == SPEEDBOOTS_ICON_PATH,
		"reward item_name should resolve to the item sprite path"
	)
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_path({"item_data": {"name": "banana"}}) == "res://assets/sprites/items/banana.png",
		"item_data name should resolve to the item sprite path"
	)
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_path({}) == "",
		"missing icon data should resolve to an empty path"
	)


func _verify_texture_resolution() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.0, 0.0, 1.0))
	var preloaded_texture: Texture2D = ImageTexture.create_from_image(image)
	_expect(
		StageClearResultRewardIconResolver.get_preloaded_reward_icon_texture({"item_data": {"icon_texture": preloaded_texture}}) == preloaded_texture,
		"preloaded item_data icon_texture should be returned directly"
	)
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_texture({"item_data": {"icon_texture": preloaded_texture}}, {}) == preloaded_texture,
		"preloaded icon_texture should bypass path loading"
	)

	var texture_cache: Dictionary = {}
	var loaded: Texture2D = StageClearResultRewardIconResolver.get_reward_icon_texture({"icon_path": SPEEDBOOTS_ICON_PATH}, texture_cache)
	_expect(loaded != null, "icon resolver should load an on-disk reward icon")
	_expect(texture_cache.has(SPEEDBOOTS_ICON_PATH), "icon resolver should cache path-loaded textures")
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_texture({"icon_path": SPEEDBOOTS_ICON_PATH}, texture_cache) == loaded,
		"icon resolver should reuse cached path-loaded textures"
	)


func _verify_scene_delegates_icon_resolver() -> void:
	var scene := StageClearResultScene.new()
	var texture: Texture2D = scene._get_reward_icon_texture({"item_data": {"icon_path": SPEEDBOOTS_ICON_PATH}})
	_expect(texture != null, "result scene icon wrapper should load item_data icon paths")
	_expect(scene._reward_icon_cache.has(SPEEDBOOTS_ICON_PATH), "result scene icon wrapper should keep its local cache")
	_expect(
		scene._get_reward_icon_texture({"item_name": "speedboots"}) == texture,
		"result scene icon wrapper should reuse cached item-name fallback paths"
	)
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
