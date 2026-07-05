extends SceneTree

const StageClearResultRewardVisualResolver := preload("res://scripts/ui/stage_clear_result_reward_visual_resolver.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reward_colors()
	_verify_reward_badges()
	_verify_reward_label_visual_state()
	_verify_reward_icon_palettes()
	_verify_reward_item_icon_visual_state()
	_verify_reward_card_visual_state()
	_verify_reward_source_chip_visual_state()
	_verify_fallback_reward_icon_visual_state()
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


func _verify_reward_label_visual_state() -> void:
	var empty_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_label_visual_state({}, Vector2.ZERO, 10.0, 1.0, 1.0, 0.0, 72.0)
	_expect(empty_state.is_empty(), "reward label visual state should ignore missing rewards")
	var state: Dictionary = StageClearResultRewardVisualResolver.get_reward_label_visual_state(
		{
			"reward": {"type": "active", "label": "A"},
			"reward_emerge": 0.5,
			"phase": 0.0,
		},
		Vector2(100.0, 200.0),
		40.0,
		2.0,
		0.8,
		0.0,
		72.0
	)
	_expect(str((state.get("reward", {}) as Dictionary).get("label", "")) == "A", "reward label visual state should pass through the reward")
	_expect(str(state.get("reward_type", "")) == "active", "reward label visual state should expose reward type")
	_expect(is_equal_approx(float(state.get("emerge_eased", 0.0)), 0.5), "reward label visual state should smooth emerge progress")
	_expect(is_equal_approx(float(state.get("alpha", 0.0)), 0.4), "reward label visual state should combine emerge and global alpha")
	_expect(Vector2(state.get("anchor", Vector2.ZERO)) == Vector2(100.0, 68.0), "reward label visual state should resolve the label anchor")


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


func _verify_reward_item_icon_visual_state() -> void:
	var state: Dictionary = StageClearResultRewardVisualResolver.get_reward_item_icon_visual_state(
		"active",
		Vector2(100.0, 200.0),
		2.0,
		0.5
	)
	_expect(Rect2(state.get("icon_rect", Rect2())) == Rect2(Vector2(4.0, 104.0), Vector2(192.0, 192.0)), "item icon visual state should center the icon rect")
	_expect(is_equal_approx(float(state.get("disc_radius", 0.0)), 120.0), "item icon visual state should scale the disc radius")
	_expect(state.get("disc_fill", Color.TRANSPARENT) == Color(0.06, 0.20, 0.28, 0.44), "item icon visual state should apply alpha to the disc")
	_expect(state.get("ring_color", Color.TRANSPARENT) == Color(0.55, 0.92, 1.0, 0.5), "item icon visual state should apply alpha to the rim")
	_expect(Rect2(state.get("fallback_text_rect", Rect2())).size == Vector2(228.0, 72.0), "item icon fallback text rect should scale with the disc")
	_expect(int(state.get("fallback_font_preferred_size", 0)) == 44, "item icon fallback preferred font size should scale")


func _verify_reward_card_visual_state() -> void:
	var state: Dictionary = StageClearResultRewardVisualResolver.get_reward_card_visual_state(
		{"type": "mythic"},
		Rect2(Vector2(10.0, 20.0), Vector2(148.0, 112.0)),
		2.0,
		0.5
	)
	_expect(str(state.get("reward_type", "")) == "mythic", "reward card visual state should expose the reward type")
	_expect(state.get("base_color", Color.TRANSPARENT) == Color(0.32, 0.10, 0.50, 0.09), "reward card visual state should apply alpha to the base color")
	_expect(Rect2(state.get("badge_rect", Rect2())) == Rect2(Vector2(26.0, 34.0), Vector2(116.0, 40.0)), "reward card badge rect should scale from the card origin")
	_expect(str(state.get("badge_text", "")) == "MYTHIC", "reward card visual state should include the badge text")
	_expect(Rect2(state.get("icon_rect", Rect2())) == Rect2(Vector2(94.0, 80.0), Vector2(128.0, 108.0)), "reward card icon rect should scale from the card origin")
	_expect(Rect2(state.get("label_rect", Rect2())) == Rect2(Vector2(26.0, 188.0), Vector2(116.0, 44.0)), "reward card label rect should scale from the card origin")
	_expect(int(state.get("label_font_preferred_size", 0)) == 28, "reward card label font size should scale")


func _verify_reward_source_chip_visual_state() -> void:
	var empty_state: Dictionary = StageClearResultRewardVisualResolver.get_reward_source_chip_visual_state(
		"stage",
		"",
		Rect2(Vector2.ZERO, Vector2(148.0, 112.0)),
		1.0,
		1.0,
		"stage",
		"box"
	)
	_expect(empty_state.is_empty(), "source chip visual state should ignore missing labels")
	var state: Dictionary = StageClearResultRewardVisualResolver.get_reward_source_chip_visual_state(
		"box",
		"BOX",
		Rect2(Vector2(10.0, 20.0), Vector2(148.0, 112.0)),
		2.0,
		0.5,
		"stage",
		"box"
	)
	_expect(Rect2(state.get("rect", Rect2())) == Rect2(Vector2(14.0, 34.0), Vector2(128.0, 40.0)), "source chip rect should anchor to the card top-right")
	_expect(state.get("fill", Color.TRANSPARENT) == Color(0.46, 0.22, 0.08, 0.36), "source chip fill should apply alpha to the source color")
	_expect(int(state.get("font_preferred_size", 0)) == 20, "source chip font size should scale")


func _verify_fallback_reward_icon_visual_state() -> void:
	var state: Dictionary = StageClearResultRewardVisualResolver.get_fallback_reward_icon_visual_state(
		"passive",
		Rect2(Vector2(10.0, 20.0), Vector2(60.0, 40.0)),
		0.5
	)
	_expect(Vector2(state.get("center", Vector2.ZERO)) == Vector2(40.0, 40.0), "fallback reward icon should use the rect center")
	_expect(is_equal_approx(float(state.get("radius", 0.0)), 16.8), "fallback reward icon should use the smaller rect axis")
	_expect(state.get("fill", Color.TRANSPARENT) == Color(0.50, 0.36, 0.10, 0.42), "fallback reward icon should apply alpha to the reward color")


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
	_expect(not state.has("disc_radius"), "starpoint visual state should not use the old coin disc")
	_expect(not state.has("orbit_rect"), "starpoint visual state should not use the old coin orbit")
	_expect(is_equal_approx(float(state.get("star_radius", 0.0)), 68.0), "starpoint visual state should scale the in-game drop star radius")
	_expect(is_equal_approx(float(state.get("inner_radius", 0.0)), 34.0), "starpoint visual state should use the in-game half-radius valleys")
	_expect(Vector2(state.get("star_center", Vector2.ZERO)) == Vector2(100.0, 184.0), "starpoint visual state should offset the drop center")
	_expect(is_equal_approx(float(state.get("sparkle_alpha", 0.0)), 0.125), "starpoint visual state should combine alpha and emerge progress")
	var glow_layers: Array = state.get("glow_layers", []) if state.get("glow_layers", []) is Array else []
	_expect(glow_layers.size() == 4, "starpoint visual state should expose the in-game four-layer glow")
	if glow_layers.size() == 4:
		var first_layer: Dictionary = glow_layers[0]
		_expect(is_equal_approx(float(first_layer.get("radius", 0.0)), 272.0), "starpoint glow should use the in-game 4x outer radius")
		var glow_color: Color = first_layer.get("color", Color.TRANSPARENT)
		_expect(glow_color.r == 1.0 and is_equal_approx(glow_color.g, 0.45) and is_equal_approx(glow_color.b, 0.74), "starpoint glow should use the in-game pink glow palette")
	_expect(state.get("star_outline", Color.TRANSPARENT) == Color(1.0, 1.0, 0.0, 0.5), "starpoint outline should use the in-game yellow palette")
	_expect(Rect2(state.get("text_rect", Rect2())).size == Vector2(224.0, 64.0), "starpoint visual state should scale the amount label rect")
	_expect(int(state.get("amount_font_size", 0)) == 44, "starpoint visual state should scale the amount font")


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
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var box_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var box_presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_presenter.gd")
	var box_draw_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	var card_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
	var float_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_reward_float_draw_helper.gd")
	_expect(
		source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0
		and draw_scene_handler_source.find("StageClearResultBoxSceneHandler.draw_floating_boxes") >= 0
		and box_scene_handler_source.find("StageClearResultBoxPresenter.draw_floating_boxes") >= 0
		and box_presenter_source.find("StageClearResultBoxDrawHelper.draw_floating_result_box") >= 0
		and box_draw_helper_source.find("StageClearResultRewardFloatDrawHelper.draw_reward_label") >= 0
		and card_helper_source.find("StageClearResultRewardVisualResolver.get_reward_card_visual_state") >= 0
		and card_helper_source.find("StageClearResultRewardVisualResolver.get_reward_badge") >= 0
		and card_helper_source.find("StageClearResultRewardVisualResolver.get_result_reward_source_label") >= 0
		and float_helper_source.find("StageClearResultRewardVisualResolver.get_reward_label_visual_state") >= 0
		and float_helper_source.find("StageClearResultRewardVisualResolver.get_reward_item_icon_visual_state") >= 0,
		"result scene should delegate reward visuals through scene handler, presenter/draw helpers, and visual resolver"
	)
	for removed_wrapper in [
		"func _get_reward_color(",
		"func _get_reward_badge(",
		"func _get_result_reward_source_label(",
		"func _get_result_reward_source_labels(",
		"func _get_result_reward_source_color(",
	]:
		_expect(
			source.find(removed_wrapper) < 0,
			"result scene should not keep visual pass-through wrapper %s" % removed_wrapper
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
