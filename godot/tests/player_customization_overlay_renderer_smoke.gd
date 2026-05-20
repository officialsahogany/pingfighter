extends SceneTree

const GameplayActorModuleCatalog := preload("res://scripts/resources/gameplay_actor_module_catalog.gd")
const PlayerCustomizationOverlayRenderer := preload("res://scripts/characters/player_customization_overlay_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_registration()
	_verify_smasher_overlay_commands_use_base_frame()
	_verify_missing_and_unsupported_overlays_are_skipped()
	_verify_optimus_overlay_commands_emit()
	_verify_paddle_scale_metadata_scales_dest_rect()
	_verify_energy_alpha_metadata_dims_modulate()
	_verify_core_glow_slot_routes_through_front_layer()
	_verify_default_texture_key_is_character_aware()
	_verify_overlay_commands_inherit_base_rotation()

	if _failures.is_empty():
		print("player_customization_overlay_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var spec: Dictionary = GameplayActorModuleCatalog.new().get_spec("player_customization_overlay_renderer")
	_expect(
		str(spec.get("path", "")) == "res://scripts/characters/player_customization_overlay_renderer.gd",
		"player customization overlay renderer should be registered in the actor module catalog"
	)


func _verify_smasher_overlay_commands_use_base_frame() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.2, 0.8, 1.0, 1.0))
	var context := {
		"selected_character_type": "smasher",
		"player_customization_overlay_slots": {
			"back": {
				"texture": texture,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
			"outfit_accent": {
				"enabled": false,
				"texture": texture,
			},
			"paddle": {
				"mirror_policy": "mirror_ok",
				"motions": {
					"walk": {
						"directions": {
							"right": {
								"texture": texture,
								"grid_cols": 4,
								"grid_rows": 2,
								"frame_count": 8,
								"cell_width": 160.0,
								"cell_height": 160.0,
							}
						}
					}
				}
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"walk",
		3,
		Rect2(10.0, 20.0, 160.0, 160.0),
		Rect2(480.0, 0.0, 160.0, 160.0),
		context,
		{
			"direction": "left",
			"grid_cols": 4,
			"grid_rows": 2,
			"frame_count": 8,
			"cell_width": 160.0,
			"cell_height": 160.0,
		}
	)
	var back_commands: Array = renderer.build_draw_commands(context, base_plan, "back")
	var front_commands: Array = renderer.build_draw_commands(context, base_plan, "front")

	_expect(back_commands.size() == 1, "back layer should include only the back slot")
	_expect(front_commands.size() == 1, "front layer should skip disabled and missing slots")
	if back_commands.size() == 1:
		var back_command: Dictionary = back_commands[0]
		_expect(str(back_command.get("slot_id", "")) == "back", "back command should keep the back slot id")
		_expect(int(back_command.get("frame_index", -1)) == 3, "back overlay should reuse the base frame index")
		_expect(_rect_equal(back_command.get("source_rect", Rect2()), Rect2(480.0, 0.0, 160.0, 160.0)), "back overlay should slice frame 3 from its sheet")
	if front_commands.size() == 1:
		var paddle_command: Dictionary = front_commands[0]
		_expect(str(paddle_command.get("slot_id", "")) == "paddle", "front command should use the paddle slot")
		_expect(int(paddle_command.get("frame_index", -1)) == 3, "paddle overlay should reuse the base frame index")
		_expect(bool(paddle_command.get("flip_h", false)), "paddle overlay should mirror the right sheet for a left-facing base")
		_expect(_rect_equal(paddle_command.get("dest_rect", Rect2()), Rect2(10.0, 20.0, 160.0, 160.0)), "paddle overlay should default to the base destination rect")


func _verify_missing_and_unsupported_overlays_are_skipped() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(1.0, 0.8, 0.2, 1.0))
	var smasher_context := {
		"selected_character_type": "smasher",
		"player_customization_overlay_slots": {
			"paddle": {
				"motion_id": "idle",
				"texture": texture,
			},
		},
	}
	var walk_plan: Dictionary = renderer.build_base_plan(
		"walk",
		1,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(160.0, 0.0, 160.0, 160.0),
		smasher_context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	_expect(renderer.build_draw_commands(smasher_context, walk_plan, "front").is_empty(), "motion-specific overlays should not draw on the wrong motion")

	var disabled_context := smasher_context.duplicate(true)
	disabled_context["player_customization_overlays_enabled"] = false
	_expect(renderer.build_draw_commands(disabled_context, walk_plan, "front").is_empty(), "global overlay toggle should suppress overlay commands")

	var viper_context := smasher_context.duplicate(true)
	viper_context["selected_character_type"] = "viper"
	var viper_plan: Dictionary = renderer.build_base_plan(
		"walk",
		1,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(160.0, 0.0, 160.0, 160.0),
		viper_context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	_expect(renderer.build_draw_commands(viper_context, viper_plan, "front").is_empty(), "unsupported characters (e.g. viper) should not emit overlay commands yet")


func _verify_optimus_overlay_commands_emit() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var paddle_texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.4, 0.7, 1.0, 1.0))
	var core_texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.9, 0.5, 0.2, 1.0))
	var context := {
		"selected_character_type": "optimus",
		"player_customization_overlay_slots": {
			"paddle": {
				"texture": paddle_texture,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
			"core_glow": {
				"texture": core_texture,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"idle",
		2,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(320.0, 0.0, 160.0, 160.0),
		context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var front_commands: Array = renderer.build_draw_commands(context, base_plan, "front")
	_expect(front_commands.size() == 2, "optimus front layer should emit both paddle and core_glow commands")
	var slot_ids: Array = []
	for command_raw in front_commands:
		if command_raw is Dictionary:
			slot_ids.append(str((command_raw as Dictionary).get("slot_id", "")))
	_expect(slot_ids.has("paddle") and slot_ids.has("core_glow"), "optimus front layer should include paddle and core_glow")


func _verify_paddle_scale_metadata_scales_dest_rect() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.5, 0.9, 1.0, 1.0))
	var context := {
		"selected_character_type": "optimus",
		"player_paddle_scale": 1.5,
		"player_customization_overlay_slots": {
			"paddle": {
				"texture": texture,
				"scale_from_player_paddle": true,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"idle",
		0,
		Rect2(100.0, 100.0, 200.0, 200.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var front_commands: Array = renderer.build_draw_commands(context, base_plan, "front")
	_expect(front_commands.size() == 1, "paddle slot should emit one command when scale_from_player_paddle is set")
	if front_commands.size() == 1:
		var paddle_command: Dictionary = front_commands[0]
		var dest: Rect2 = _as_rect2(paddle_command.get("dest_rect", Rect2()))
		_expect(is_equal_approx(dest.size.x, 300.0) and is_equal_approx(dest.size.y, 300.0), "paddle dest_rect size should multiply by player_paddle_scale (200 * 1.5 = 300)")
		_expect(is_equal_approx(dest.get_center().x, 200.0) and is_equal_approx(dest.get_center().y, 200.0), "paddle dest_rect should scale around the original center")


func _verify_energy_alpha_metadata_dims_modulate() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(1.0, 0.8, 0.3, 1.0))
	var context := {
		"selected_character_type": "optimus",
		"player_energy_ratio": 0.4,
		"player_customization_overlay_slots": {
			"core_glow": {
				"texture": texture,
				"alpha_from_energy_ratio": true,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"idle",
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var front_commands: Array = renderer.build_draw_commands(context, base_plan, "front")
	_expect(front_commands.size() == 1, "core_glow slot should emit one command when alpha_from_energy_ratio is set")
	if front_commands.size() == 1:
		var glow_command: Dictionary = front_commands[0]
		var modulate: Color = glow_command.get("modulate", Color.WHITE) as Color
		_expect(is_equal_approx(modulate.a, 0.4), "core_glow modulate alpha should equal player_energy_ratio (0.4)")


func _verify_core_glow_slot_routes_through_front_layer() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.6, 0.3, 0.9, 1.0))
	var context := {
		"selected_character_type": "optimus",
		"player_customization_overlay_slots": {
			"core_glow": {
				"texture": texture,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"idle",
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	_expect(renderer.build_draw_commands(context, base_plan, "back").is_empty(), "core_glow should not appear on the back layer")
	_expect(renderer.build_draw_commands(context, base_plan, "front").size() == 1, "core_glow should appear on the front layer")


func _verify_default_texture_key_is_character_aware() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var smasher_texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.2, 0.8, 1.0, 1.0))
	var optimus_texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.9, 0.4, 0.2, 1.0))
	var texture_map := {
		"smasher_overlay_paddle": smasher_texture,
		"optimus_overlay_paddle": optimus_texture,
	}
	var smasher_context := {
		"selected_character_type": "smasher",
		"player_customization_overlay_textures": texture_map,
		"player_customization_overlay_slots": {
			"paddle": {
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var optimus_context := smasher_context.duplicate(true)
	optimus_context["selected_character_type"] = "optimus"
	var smasher_plan: Dictionary = renderer.build_base_plan(
		"idle",
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		smasher_context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var optimus_plan: Dictionary = renderer.build_base_plan(
		"idle",
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		optimus_context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var smasher_commands: Array = renderer.build_draw_commands(smasher_context, smasher_plan, "front")
	var optimus_commands: Array = renderer.build_draw_commands(optimus_context, optimus_plan, "front")
	_expect(smasher_commands.size() == 1, "smasher paddle should resolve via smasher_overlay_* texture key")
	_expect(optimus_commands.size() == 1, "optimus paddle should resolve via optimus_overlay_* texture key")
	if smasher_commands.size() == 1 and optimus_commands.size() == 1:
		_expect((smasher_commands[0] as Dictionary).get("texture") == smasher_texture, "smasher should pull the smasher_overlay_* texture, not the optimus one")
		_expect((optimus_commands[0] as Dictionary).get("texture") == optimus_texture, "optimus should pull the optimus_overlay_* texture, not the smasher one")


func _verify_overlay_commands_inherit_base_rotation() -> void:
	var renderer: Object = PlayerCustomizationOverlayRenderer.new()
	var texture: Texture2D = _make_texture(Vector2i(640, 320), Color(0.5, 0.9, 1.0, 1.0))
	var context := {
		"selected_character_type": "smasher",
		"player_sprite_rotation_degrees": 18.0,
		"player_customization_overlay_slots": {
			"paddle": {
				"texture": texture,
				"grid_cols": 4,
				"grid_rows": 2,
				"frame_count": 8,
				"cell_width": 160.0,
				"cell_height": 160.0,
			},
		},
	}
	var base_plan: Dictionary = renderer.build_base_plan(
		"walk",
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
		context,
		{"direction": "right", "grid_cols": 4, "grid_rows": 2, "frame_count": 8}
	)
	var front_commands: Array = renderer.build_draw_commands(context, base_plan, "front")
	_expect(front_commands.size() == 1, "rotated base plan should still emit the paddle overlay")
	if front_commands.size() == 1:
		var command: Dictionary = front_commands[0]
		_expect(is_equal_approx(float(base_plan.get("rotation_degrees", 0.0)), 18.0), "base plan should capture player_sprite_rotation_degrees")
		_expect(is_equal_approx(float(command.get("rotation_degrees", 0.0)), 18.0), "overlay command should inherit the base sprite rotation")


func _make_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _rect_equal(value: Variant, expected: Rect2) -> bool:
	if not (value is Rect2):
		return false
	var rect: Rect2 = value
	return rect.position.is_equal_approx(expected.position) and rect.size.is_equal_approx(expected.size)


func _as_rect2(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
