extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const PlayerCustomizationOverlayRenderer := preload("res://scripts/characters/player_customization_overlay_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	var player_customization_debug_overlay_enabled := false
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


func _init() -> void:
	_verify_f7_toggles_debug_overlay()
	_verify_debug_overlay_resource_loads()
	_verify_debug_slot_injection()
	_verify_debug_slot_stays_smasher_only()

	if _failures.is_empty():
		print("player_customization_debug_overlay_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_f7_toggles_debug_overlay() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()
	_expect(_press(input, owner, KEY_F7), "F7 should handle the customization debug toggle")
	_expect(owner.player_customization_debug_overlay_enabled, "F7 should enable the customization debug overlay")
	_expect(owner.redraw_count == 1, "F7 should queue redraw when enabling the customization debug overlay")
	_expect(_press(input, owner, KEY_F7), "F7 should handle the customization debug toggle a second time")
	_expect(not owner.player_customization_debug_overlay_enabled, "F7 should disable the customization debug overlay")
	_expect(owner.redraw_count == 2, "F7 should queue redraw when disabling the customization debug overlay")


func _verify_debug_overlay_resource_loads() -> void:
	ProjectResourceLoader.clear_caches()
	var resources := BattleResources.new()
	var cache: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
		"current_stage": 1,
	})
	var texture_value: Variant = cache.get("smasher_debug_paddle_overlay_sheet", null)
	_expect(texture_value is Texture2D, "Smasher debug paddle overlay sheet should load through BattleResources")
	if texture_value is Texture2D:
		var texture: Texture2D = texture_value
		_expect(texture.get_size().is_equal_approx(Vector2(640.0, 320.0)), "debug paddle overlay sheet should be a 4x2 160px-cell sheet")


func _verify_debug_slot_injection() -> void:
	var sheet := _make_texture(Vector2i(640, 320), Color(0.0, 1.0, 1.0, 1.0))
	var builder := BattleDrawActorContext.new()
	var source_slots: Dictionary = {}
	var source_textures: Dictionary = {}
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "smasher",
		"player_customization_debug_overlay_enabled": true,
		"player_customization_overlay_slots": source_slots,
		"player_customization_overlay_textures": source_textures,
		"textures": {
			"smasher_debug_paddle_overlay_sheet": sheet,
		},
	}, {})
	var overlay_textures: Dictionary = _get_dict(actor_context.get("player_customization_overlay_textures", {}))
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	_expect(overlay_textures.get("smasher_debug_paddle_overlay_sheet", null) == sheet, "actor context should expose the debug sheet in overlay textures")
	_expect(overlay_slots.has("paddle"), "actor context should inject the debug paddle slot when F7 is enabled")
	_expect(source_slots.is_empty(), "debug slot injection should not mutate the source overlay slot dictionary")
	_expect(source_textures.is_empty(), "debug texture injection should not mutate the source overlay texture dictionary")

	var renderer := PlayerCustomizationOverlayRenderer.new()
	var base_plan: Dictionary = renderer.build_base_plan(
		"walk",
		5,
		Rect2(10.0, 20.0, 160.0, 160.0),
		Rect2(160.0, 160.0, 160.0, 160.0),
		actor_context,
		{
			"direction": "left",
			"grid_cols": 4,
			"grid_rows": 2,
			"frame_count": 8,
			"cell_width": 160.0,
			"cell_height": 160.0,
		}
	)
	var commands: Array = renderer.build_draw_commands(actor_context, base_plan, "front")
	_expect(commands.size() == 1, "debug paddle slot should draw one front-layer command")
	if commands.size() == 1 and commands[0] is Dictionary:
		var command: Dictionary = commands[0]
		_expect(str(command.get("slot_id", "")) == "paddle", "debug command should use the paddle slot")
		_expect(bool(command.get("flip_h", false)), "debug paddle slot should mirror the right sheet for left-facing walk")
		_expect(_rect_equal(command.get("source_rect", Rect2()), Rect2(160.0, 160.0, 160.0, 160.0)), "debug paddle slot should reuse the base frame index")


func _verify_debug_slot_stays_smasher_only() -> void:
	var sheet := _make_texture(Vector2i(640, 320), Color(1.0, 0.0, 1.0, 1.0))
	var builder := BattleDrawActorContext.new()
	var disabled_context: Dictionary = builder.build({
		"selected_character_type": "smasher",
		"player_customization_debug_overlay_enabled": false,
		"textures": {
			"smasher_debug_paddle_overlay_sheet": sheet,
		},
	}, {})
	_expect(_get_dict(disabled_context.get("player_customization_overlay_slots", {})).is_empty(), "debug paddle slot should stay absent while F7 is off")

	var viper_context: Dictionary = builder.build({
		"selected_character_type": "viper",
		"player_customization_debug_overlay_enabled": true,
		"textures": {
			"smasher_debug_paddle_overlay_sheet": sheet,
		},
	}, {})
	_expect(_get_dict(viper_context.get("player_customization_overlay_slots", {})).is_empty(), "debug paddle slot should not attach to non-Smasher characters")


func _press(input: Object, owner: Object, keycode: int) -> bool:
	var event := InputEventKey.new()
	event.pressed = true
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = keycode
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = keycode
	return bool(input.handle_input(event, owner, null, Callable(self, "_get_module"), {}))


func _get_module(_key: String) -> Object:
	return null


func _make_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _rect_equal(value: Variant, expected: Rect2) -> bool:
	if not (value is Rect2):
		return false
	var rect: Rect2 = value
	return rect.position.is_equal_approx(expected.position) and rect.size.is_equal_approx(expected.size)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
