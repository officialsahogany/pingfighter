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
	var texture: Texture2D = StageClearResultRewardIconResolver.get_reward_icon_texture(
		{"item_data": {"icon_path": SPEEDBOOTS_ICON_PATH}},
		scene._reward_icon_cache
	)
	_expect(texture != null, "result scene icon cache should load item_data icon paths")
	_expect(scene._reward_icon_cache.has(SPEEDBOOTS_ICON_PATH), "result scene should keep icon resolver cache data")
	_expect(
		StageClearResultRewardIconResolver.get_reward_icon_texture(
			{"item_name": "speedboots"},
			scene._reward_icon_cache
		) == texture,
		"result scene icon cache should reuse cached item-name fallback paths"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var card_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
	var float_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")
	_expect(
		card_source.find("StageClearResultRewardIconResolver.get_reward_icon_texture") >= 0
		and float_source.find("StageClearResultRewardIconResolver.get_reward_icon_texture") >= 0,
		"reward draw helpers should call the reward icon resolver directly"
	)
	_expect(
		source.find("func _get_reward_icon_texture") < 0,
		"result scene should not keep reward icon pass-through wrappers"
	)
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
