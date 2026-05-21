extends SceneTree

const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reward_colors()
	_verify_reward_badges()
	_verify_source_colors()
	_verify_scene_delegates_visual_resolver()

	if _failures.is_empty():
		print("stage_clear_result_reward_visual_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reward_colors() -> void:
	_expect(StageClearResultRewardVisualResolver.get_reward_color("active") == Color(0.10, 0.52, 0.62, 1.0), "active rewards should use the active color")
	_expect(StageClearResultRewardVisualResolver.get_reward_color("passive") == Color(0.50, 0.36, 0.10, 1.0), "passive rewards should use the passive color")
	_expect(StageClearResultRewardVisualResolver.get_reward_color("mythic") == Color(0.32, 0.10, 0.50, 1.0), "mythic rewards should use the mythic color")
	_expect(StageClearResultRewardVisualResolver.get_reward_color("starpoint") == Color(0.86, 0.52, 0.10, 1.0), "starpoint rewards should use the starpoint color")
	_expect(StageClearResultRewardVisualResolver.get_reward_color("skill") == Color(0.18, 0.36, 0.58, 1.0), "skill rewards should use the perk color")
	_expect(StageClearResultRewardVisualResolver.get_reward_color("unknown") == Color(0.40, 0.32, 0.20, 1.0), "unknown rewards should use the fallback color")


func _verify_reward_badges() -> void:
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "active"}) == "ACTIVE", "active rewards should use ACTIVE badge")
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "passive"}) == "PASSIVE", "passive rewards should use PASSIVE badge")
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "mythic"}) == "MYTHIC", "mythic rewards should use MYTHIC badge")
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "starpoint"}) == "PERK", "starpoint rewards should use PERK badge")
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "skill"}) == "PERK", "skill rewards should use PERK badge")
	_expect(StageClearResultRewardVisualResolver.get_reward_badge({"type": "gold"}) == "REWARD", "unknown rewards should use REWARD badge")


func _verify_source_colors() -> void:
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_color("stage", "stage", "box") == Color(0.04, 0.32, 0.36, 1.0),
		"stage reward source should use the stage chip color"
	)
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_color("box", "stage", "box") == Color(0.46, 0.22, 0.08, 1.0),
		"box reward source should use the box chip color"
	)
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_color("other", "stage", "box") == Color(0.18, 0.24, 0.28, 1.0),
		"unknown reward sources should use the fallback chip color"
	)


func _verify_scene_delegates_visual_resolver() -> void:
	var scene := StageClearResultScene.new()
	_expect(scene._get_reward_color("mythic") == StageClearResultRewardVisualResolver.get_reward_color("mythic"), "result scene reward color wrapper should delegate")
	_expect(scene._get_reward_badge({"type": "passive"}) == "PASSIVE", "result scene badge wrapper should delegate")
	_expect(scene._get_result_reward_source_color("stage") == Color(0.04, 0.32, 0.36, 1.0), "result scene source color wrapper should delegate")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
