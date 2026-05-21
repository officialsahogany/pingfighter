extends SceneTree

const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reward_colors()
	_verify_reward_badges()
	_verify_reward_icon_palettes()
	_verify_starpoint_visual_state()
	_verify_source_labels()
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


func _verify_reward_icon_palettes() -> void:
	var active_palette: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_palette("active")
	_expect(active_palette.get("disc_color", Color.TRANSPARENT) == Color(0.06, 0.20, 0.28, 0.88), "active item icon should use the active disc color")
	_expect(active_palette.get("rim_color", Color.TRANSPARENT) == Color(0.55, 0.92, 1.0, 1.0), "active item icon should use the active rim color")
	var passive_palette: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_palette("passive")
	_expect(passive_palette.get("disc_color", Color.TRANSPARENT) == Color(0.22, 0.14, 0.04, 0.88), "passive item icon should use the passive disc color")
	_expect(passive_palette.get("rim_color", Color.TRANSPARENT) == Color(1.0, 0.84, 0.48, 1.0), "passive item icon should use the passive rim color")
	var mythic_palette: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_palette("mythic")
	_expect(mythic_palette.get("disc_color", Color.TRANSPARENT) == Color(0.20, 0.06, 0.34, 0.92), "mythic item icon should use the mythic disc color")
	_expect(mythic_palette.get("rim_color", Color.TRANSPARENT) == Color(1.0, 0.78, 0.30, 1.0), "mythic item icon should use the mythic rim color")
	var fallback_palette: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_palette("unknown")
	_expect(fallback_palette.get("disc_color", Color.TRANSPARENT) == Color(0.18, 0.18, 0.24, 0.88), "unknown item icon should use the fallback disc color")
	_expect(fallback_palette.get("rim_color", Color.TRANSPARENT) == Color(0.85, 0.85, 0.92, 1.0), "unknown item icon should use the fallback rim color")


func _verify_starpoint_visual_state() -> void:
	var state: Dictionary = StageClearResultRewardVisualResolver.get_reward_starpoint_visual_state(
		0,
		Vector2(100.0, 200.0),
		2.0,
		0.5,
		0.25,
		0.0,
		0.0
	)
	_expect(int(state.get("amount", 0)) == 1, "starpoint visual state should clamp amount to at least one")
	_expect(is_equal_approx(float(state.get("disc_radius", 0.0)), 120.0), "starpoint visual state should scale disc radius")
	_expect(is_equal_approx(float(state.get("star_radius", 0.0)), 84.0), "starpoint visual state should scale star radius")
	_expect(is_equal_approx(float(state.get("yaw_width", 0.0)), 1.0), "starpoint visual state should face forward at zero spin")
	_expect(bool(state.get("front_face", false)), "starpoint visual state should mark the forward face")
	_expect(Vector2(state.get("star_center", Vector2.ZERO)) == Vector2(100.0, 180.0), "starpoint visual state should offset the star center")
	_expect(is_equal_approx(float(state.get("sparkle_alpha", 0.0)), 0.125), "starpoint visual state should combine alpha and emerge progress")
	_expect(Rect2(state.get("text_rect", Rect2())).size == Vector2(240.0, 60.0), "starpoint visual state should scale the amount label rect")


func _verify_source_labels() -> void:
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_label("stage", "stage", "box", "인게임", "상자") == "인게임",
		"stage reward source should use the in-game chip label"
	)
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_label("box", "stage", "box", "인게임", "상자") == "상자",
		"box reward source should use the box chip label"
	)
	_expect(
		StageClearResultRewardVisualResolver.get_result_reward_source_label("other", "stage", "box", "인게임", "상자") == "",
		"unknown reward sources should not expose a chip label"
	)
	var labels: Dictionary = StageClearResultRewardVisualResolver.get_result_reward_source_labels("stage", "box", "인게임", "상자")
	_expect(str(labels.get("stage", "")) == "인게임", "source labels should expose the in-game label")
	_expect(str(labels.get("box", "")) == "상자", "source labels should expose the box label")


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
	_expect(scene._get_result_reward_source_label("box") == "상자", "result scene source-label wrapper should delegate")
	_expect(scene._get_result_reward_source_color("stage") == Color(0.04, 0.32, 0.36, 1.0), "result scene source color wrapper should delegate")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
