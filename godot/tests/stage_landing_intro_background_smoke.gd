extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageLandingIntro := preload("res://scripts/core/stage_landing_intro.gd")

const STAGE_BACKGROUNDS := {
	3: "res://assets/sprites/hud/stage3_landing_zoom_background_imagegen_v1.png",
	4: "res://assets/sprites/hud/stage4_landing_zoom_background_imagegen_v1.png",
}


class FakeOwner:
	extends RefCounted

	var current_stage := 1


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


var _failures: Array[String] = []


func _init() -> void:
	for stage in STAGE_BACKGROUNDS.keys():
		_verify_stage_background(int(stage), str(STAGE_BACKGROUNDS[stage]))

	if _failures.is_empty():
		print("stage_landing_intro_background_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_background(stage: int, path: String) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "landing background should load: %s" % path)
	if texture != null:
		_expect(texture.get_width() == 1254, "landing background should keep expected width: %s" % path)
		_expect(texture.get_height() == 1254, "landing background should keep expected height: %s" % path)

	var owner := FakeOwner.new()
	owner.current_stage = stage
	var intro := StageLandingIntro.new()
	_expect(intro.begin(owner, FakeRegistry.new()), "landing intro should begin for stage %d" % stage)
	_expect(intro.is_active(), "landing intro should become active for stage %d" % stage)
	var background: Variant = intro.get("background_texture")
	_expect(background is Texture2D, "landing intro should cache a Texture2D for stage %d" % stage)
	if background is Texture2D:
		_expect((background as Texture2D).get_width() == 1254, "cached background should keep expected width for stage %d" % stage)
		_expect((background as Texture2D).get_height() == 1254, "cached background should keep expected height for stage %d" % stage)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
