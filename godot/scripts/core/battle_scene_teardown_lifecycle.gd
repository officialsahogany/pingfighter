extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")


func exit_tree(_owner: Node, registry: Object, cached_module_getter: Callable, callbacks: Dictionary) -> void:
	var logo_intro: Object = _get_module(cached_module_getter, "penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("cleanup"):
		logo_intro.cleanup()
	var audio: Object = _get_module(cached_module_getter, "game_audio")
	if audio != null and audio.has_method("stop_bgm"):
		audio.stop_bgm()
	ProjectResourceLoader.clear_caches()
	SkillOrbTextureNormalizer.clear_cache()
	if registry != null and registry.has_method("clear_all"):
		registry.clear_all()
	_call(callbacks, "clear_module_cache")


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
