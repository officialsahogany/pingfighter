extends SceneTree

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const Stage1PlayfieldRenderer := preload("res://scripts/stages/stage1/stage1_playfield_renderer.gd")


func _init() -> void:
	var player_renderer := Stage1PlayerActorRenderer.new()
	_expect(bool(player_renderer.call("_uses_smasher_body_motion", {"selected_character_type": "smasher"})), "Smasher should keep body hover motion")
	_expect(bool(player_renderer.call("_uses_smasher_body_motion", {})), "missing character type should default to Smasher motion")
	_expect(not bool(player_renderer.call("_uses_smasher_body_motion", {"selected_character_type": "soldier"})), "Commando runtime id should not use Smasher body motion")
	_expect(not bool(player_renderer.call("_uses_smasher_body_motion", {"selected_character_type": "commando"})), "Commando alias should not use Smasher body motion")
	_expect(not bool(player_renderer.call("_uses_smasher_body_motion", {"selected_character_type": "viper"})), "Viper should not use Smasher body motion")

	_expect(is_equal_approx(float(player_renderer.call("_get_player_hover_amplitude", {
		"selected_character_type": "smasher",
		"player_hover_amplitude": 9.0,
	})), 9.0), "Smasher should preserve configured hover amplitude")
	_expect(is_equal_approx(float(player_renderer.call("_get_player_hover_amplitude", {
		"selected_character_type": "viper",
		"player_hover_amplitude": 99.0,
	})), 0.0), "Viper should suppress shared hover amplitude")
	_expect(is_equal_approx(float(player_renderer.call("_get_player_move_bob_amplitude", {
		"selected_character_type": "soldier",
		"player_move_bob_amplitude": 99.0,
	})), 0.0), "Commando should suppress shared move bob")
	_expect(is_equal_approx(float(player_renderer.call("_get_player_idle_breath_y", {
		"selected_character_type": "commando",
		"player_idle_breath_y": 99.0,
	})), 0.0), "Commando should suppress shared idle vertical breath")

	var playfield_renderer := Stage1PlayfieldRenderer.new()
	var base_context := {
		"player_pos": Vector2(0.0, 100.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_sprite_draw_size": Vector2(250.0, 120.0),
		"player_anim_clock": PI / 9.0,
		"player_hover_amplitude": 9.0,
		"player_move_bob_amplitude": 11.0,
	}
	var base_y := 100.0 + 50.0 - 120.0 + 12.0
	var viper_context: Dictionary = base_context.duplicate()
	viper_context["selected_character_type"] = "viper"
	var viper_rect: Rect2 = playfield_renderer.call("_get_player_afterimage_rect", viper_context, false)
	_expect(is_equal_approx(viper_rect.position.y, base_y), "Viper dash afterimage should not inherit Smasher hover/bob offset")

	var smasher_context: Dictionary = base_context.duplicate()
	smasher_context["selected_character_type"] = "smasher"
	var smasher_rect: Rect2 = playfield_renderer.call("_get_player_afterimage_rect", smasher_context, false)
	_expect(smasher_rect.position.y < base_y, "Smasher dash afterimage should keep its hover/bob offset")

	print("player_sprite_body_motion_policy_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
