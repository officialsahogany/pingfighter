extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const PlayerCustomizationOverlayRenderer := preload("res://scripts/characters/player_customization_overlay_renderer.gd")

const OPTIMUS_OVERLAY_KEYS := [
	"optimus_overlay_paddle",
	"optimus_overlay_core_glow",
	"optimus_overlay_back",
	"optimus_overlay_accessory",
	"optimus_overlay_outfit_accent",
]

const OPTIMUS_OVERLAY_SLOT_IDS := ["paddle", "core_glow", "back", "accessory", "outfit_accent"]

var _failures: Array[String] = []


func _init() -> void:
	_verify_optimus_base_sheets_route_to_generic_context_keys()
	_verify_optimus_overlay_textures_pass_through()
	_verify_optimus_default_overlay_slots_inject_when_textures_available()
	_verify_optimus_default_slots_respect_custom_overrides()
	_verify_optimus_paddle_slot_carries_scale_metadata()
	_verify_optimus_core_glow_slot_carries_alpha_metadata()
	_verify_optimus_overlay_runtime_metadata_applies()
	_verify_smasher_unaffected_by_optimus_overlay_routing()
	_verify_io_alias_routes_through_optimus_branch()

	if _failures.is_empty():
		print("optimus_actor_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_optimus_base_sheets_route_to_generic_context_keys() -> void:
	var builder := BattleDrawActorContext.new()
	var stale_smasher_strip := _make_texture(Vector2i(1500, 120), Color(0.9, 0.35, 0.15, 1.0))
	var walk_left := _make_texture(Vector2i(640, 320), Color(0.2, 0.6, 0.9, 1.0))
	var walk_right := _make_texture(Vector2i(640, 320), Color(0.25, 0.65, 0.95, 1.0))
	var idle_sheet := _make_texture(Vector2i(640, 320), Color(0.3, 0.7, 1.0, 1.0))
	var attack_left := _make_texture(Vector2i(640, 320), Color(0.35, 0.75, 1.0, 1.0))
	var attack_right := _make_texture(Vector2i(640, 320), Color(0.4, 0.8, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"optimus_energy_ratio": 0.42,
		"textures": {
			"player_sprite_texture": stale_smasher_strip,
			"optimus_player_walk_left_sheet": walk_left,
			"optimus_player_walk_right_sheet": walk_right,
			"optimus_player_idle_sheet": idle_sheet,
			"optimus_player_attack_left_sheet": attack_left,
			"optimus_player_attack_right_sheet": attack_right,
		},
	}, {})
	_expect(actor_context.get("player_walk_left_texture") == walk_left, "optimus walk-left sheet should route to player_walk_left_texture")
	_expect(actor_context.get("player_walk_right_texture") == walk_right, "optimus walk-right sheet should route to player_walk_right_texture")
	_expect(actor_context.get("player_idle_sprite_texture") == idle_sheet, "optimus idle sheet should route to player_idle_sprite_texture")
	_expect(actor_context.get("player_attack_left_sheet") == attack_left, "optimus attack-left sheet should route to player_attack_left_sheet")
	_expect(actor_context.get("player_attack_right_sheet") == attack_right, "optimus attack-right sheet should route to player_attack_right_sheet")
	_expect(actor_context.get("player_sprite_texture") == null, "optimus must not route 4x2 sheets through the legacy generic strip path")
	_expect(actor_context.get("player_sprite_texture") != stale_smasher_strip, "optimus must ignore stale legacy Smasher generic sprite textures")
	_expect(int(actor_context.get("player_hit_frame_count", 0)) == 8, "optimus directional attack sheets should advertise 8 frames")
	_expect(int(actor_context.get("player_directional_attack_grid_rows", 0)) == 2, "optimus directional attack sheets should use the 4x2 grid contract")
	_expect(is_equal_approx(float(actor_context.get("player_energy_ratio", -1.0)), 0.42), "optimus_energy_ratio should be bridged to player_energy_ratio")


func _verify_optimus_overlay_textures_pass_through() -> void:
	var builder := BattleDrawActorContext.new()
	var paddle_sheet := _make_texture(Vector2i(640, 320), Color(0.45, 0.85, 1.0, 1.0))
	var core_sheet := _make_texture(Vector2i(640, 320), Color(0.95, 0.45, 0.2, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"textures": {
			"optimus_overlay_paddle": paddle_sheet,
			"optimus_overlay_core_glow": core_sheet,
		},
	}, {})
	var overlay_textures: Dictionary = _get_dict(actor_context.get("player_customization_overlay_textures", {}))
	_expect(overlay_textures.get("optimus_overlay_paddle") == paddle_sheet, "optimus paddle overlay sheet should pass through overlay textures")
	_expect(overlay_textures.get("optimus_overlay_core_glow") == core_sheet, "optimus core_glow overlay sheet should pass through overlay textures")


func _verify_optimus_default_overlay_slots_inject_when_textures_available() -> void:
	var builder := BattleDrawActorContext.new()
	var textures: Dictionary = {}
	for key in OPTIMUS_OVERLAY_KEYS:
		textures[key] = _make_texture(Vector2i(640, 320), Color(0.5, 0.7, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"textures": textures,
	}, {})
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	for slot_id in OPTIMUS_OVERLAY_SLOT_IDS:
		_expect(overlay_slots.has(slot_id), "optimus default overlay slot %s should be injected when its texture is available" % slot_id)
		var spec: Dictionary = _get_dict(overlay_slots.get(slot_id, {}))
		_expect(str(spec.get("texture_key", "")).begins_with("optimus_overlay_"), "optimus slot %s should reference an optimus_overlay_* texture_key" % slot_id)
		_expect(str(spec.get("mirror_policy", "")) == "mirror_ok", "optimus slot %s should use mirror_ok policy" % slot_id)


func _verify_optimus_default_slots_respect_custom_overrides() -> void:
	var builder := BattleDrawActorContext.new()
	var textures: Dictionary = {}
	for key in OPTIMUS_OVERLAY_KEYS:
		textures[key] = _make_texture(Vector2i(640, 320), Color(0.5, 0.7, 1.0, 1.0))
	var custom_paddle := {"texture_key": "custom_paddle_sheet", "custom_marker": true}
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"player_customization_overlay_slots": {"paddle": custom_paddle},
		"textures": textures,
	}, {})
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	var paddle_spec: Dictionary = _get_dict(overlay_slots.get("paddle", {}))
	_expect(bool(paddle_spec.get("custom_marker", false)), "caller-supplied paddle slot must not be overwritten by optimus defaults")
	_expect(str(paddle_spec.get("texture_key", "")) == "custom_paddle_sheet", "caller-supplied texture_key should survive optimus default injection")
	_expect(overlay_slots.has("core_glow"), "non-overridden optimus slots should still get the default injection")


func _verify_optimus_paddle_slot_carries_scale_metadata() -> void:
	var builder := BattleDrawActorContext.new()
	var textures: Dictionary = {}
	for key in OPTIMUS_OVERLAY_KEYS:
		textures[key] = _make_texture(Vector2i(640, 320), Color(0.5, 0.7, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"textures": textures,
	}, {})
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	var paddle: Dictionary = _get_dict(overlay_slots.get("paddle", {}))
	_expect(bool(paddle.get("scale_from_player_paddle", false)), "optimus paddle slot must opt into player_paddle_scale auto-scaling")


func _verify_optimus_core_glow_slot_carries_alpha_metadata() -> void:
	var builder := BattleDrawActorContext.new()
	var textures: Dictionary = {}
	for key in OPTIMUS_OVERLAY_KEYS:
		textures[key] = _make_texture(Vector2i(640, 320), Color(0.5, 0.7, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"textures": textures,
	}, {})
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	var core_glow: Dictionary = _get_dict(overlay_slots.get("core_glow", {}))
	_expect(bool(core_glow.get("alpha_from_energy_ratio", false)), "optimus core_glow slot must opt into player_energy_ratio alpha modulation")


func _verify_optimus_overlay_runtime_metadata_applies() -> void:
	var builder := BattleDrawActorContext.new()
	var renderer := PlayerCustomizationOverlayRenderer.new()
	var paddle_sheet := _make_texture(Vector2i(640, 320), Color(0.4, 0.8, 1.0, 1.0))
	var core_sheet := _make_texture(Vector2i(640, 320), Color(1.0, 0.8, 0.2, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "optimus",
		"player_paddle_scale": 1.5,
		"player_energy_ratio": 0.4,
		"textures": {
			"optimus_overlay_paddle": paddle_sheet,
			"optimus_overlay_core_glow": core_sheet,
		},
	}, {})
	var base_plan: Dictionary = renderer.build_base_plan(
		"walk",
		2,
		Rect2(100.0, 120.0, 160.0, 160.0),
		Rect2(0.0, 0.0, 160.0, 160.0),
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
	var paddle_command: Dictionary = _find_command(commands, "paddle")
	var core_command: Dictionary = _find_command(commands, "core_glow")
	_expect(not paddle_command.is_empty(), "optimus paddle overlay should emit through the front layer")
	_expect(bool(paddle_command.get("flip_h", false)), "optimus left-facing overlays should mirror from the right-facing default sheet")
	var paddle_dest: Rect2 = paddle_command.get("dest_rect", Rect2())
	_expect(is_equal_approx(paddle_dest.size.x, 240.0), "optimus paddle overlay dest width should scale from player_paddle_scale")
	_expect(is_equal_approx(paddle_dest.size.y, 240.0), "optimus paddle overlay dest height should scale from player_paddle_scale")
	_expect(not core_command.is_empty(), "optimus core_glow overlay should emit through the front layer")
	var core_modulate: Color = core_command.get("modulate", Color.WHITE)
	_expect(is_equal_approx(core_modulate.a, 0.4), "optimus core_glow overlay alpha should follow player_energy_ratio")


func _verify_smasher_unaffected_by_optimus_overlay_routing() -> void:
	var builder := BattleDrawActorContext.new()
	var textures: Dictionary = {}
	for key in OPTIMUS_OVERLAY_KEYS:
		textures[key] = _make_texture(Vector2i(640, 320), Color(0.5, 0.7, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "smasher",
		"textures": textures,
	}, {})
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	for slot_id in OPTIMUS_OVERLAY_SLOT_IDS:
		_expect(not overlay_slots.has(slot_id), "smasher actor context must not auto-inject optimus default slot %s" % slot_id)


func _verify_io_alias_routes_through_optimus_branch() -> void:
	var builder := BattleDrawActorContext.new()
	var idle_sheet := _make_texture(Vector2i(640, 320), Color(0.45, 0.85, 1.0, 1.0))
	var paddle_sheet := _make_texture(Vector2i(640, 320), Color(0.4, 0.8, 1.0, 1.0))
	var actor_context: Dictionary = builder.build({
		"selected_character_type": "io",
		"textures": {
			"optimus_player_idle_sheet": idle_sheet,
			"optimus_overlay_paddle": paddle_sheet,
		},
	}, {})
	_expect(str(actor_context.get("selected_character_type", "")) == "optimus", "io alias should normalize to optimus before slot routing")
	_expect(actor_context.get("player_idle_sprite_texture") == idle_sheet, "io alias should route the optimus idle sheet just like the optimus character id")
	var overlay_slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	_expect(overlay_slots.has("paddle"), "io alias should still get the optimus default paddle slot injected")


func _make_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _find_command(commands: Array, slot_id: String) -> Dictionary:
	for command in commands:
		if command is Dictionary and str(command.get("slot_id", "")) == slot_id:
			return command
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
