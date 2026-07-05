extends SceneTree

const EffectsSpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const BattleUpdateEffectsContext := preload("res://scripts/core/battle_update_effects_context.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	var texture: Texture2D = _make_texture()
	var builder: Object = EffectsSpriteContextBuilder.new()

	var smasher_directional: Dictionary = builder.build_context({
		"player_walk_left_texture": texture,
		"player_idle_back_sheet": texture,
		"player_attack_left_sheet": texture,
		"boss_walk_right_sheet": texture,
		"boss_attack_sheet": texture,
	}, "smasher")
	_expect(str(smasher_directional.get("selected_character_type", "")) == "smasher", "Smasher sprite context should normalize character")
	_expect(bool(smasher_directional.get("player_has_sprite", false)), "Smasher directional walk should count as player sprite")
	_expect(bool(smasher_directional.get("player_has_idle_sprite", false)), "Smasher idle-back sheet should count as idle sprite")
	_expect(int(smasher_directional.get("player_sprite_frame_count", 0)) == 8, "Smasher directional walk should use 8 runtime frames")
	_expect_close(float(smasher_directional.get("player_sprite_animation_speed", 0.0)), 0.050, "Smasher directional walk should keep 0.050 cadence")
	_expect(int(smasher_directional.get("player_idle_frame_count", 0)) == 8, "Smasher idle sheet should use 8 frames")
	_expect_close(float(smasher_directional.get("player_idle_animation_speed", 0.0)), 0.15, "Smasher idle-back sheet should keep 0.15 cadence")
	_expect(bool(smasher_directional.get("player_has_attack_sheet", false)), "Smasher directional attack should enable attack sheet")
	_expect(int(smasher_directional.get("player_hit_frame_count", 0)) == 16, "Smasher directional attack should use 16 hit frames")
	_expect(bool(smasher_directional.get("player_hit_linear_frames", false)), "Smasher directional attack should use linear hit frames")
	_expect_close(float(smasher_directional.get("player_hit_anim_duration", 0.0)), 0.72, "Smasher directional attack should keep 0.72 duration")
	_expect(int(smasher_directional.get("boss_sprite_frame_count", 0)) == 16, "Dalji walk sheet should use 16 boss frames")
	_expect_close(float(smasher_directional.get("boss_sprite_animation_speed", 0.0)), 0.050, "Dalji walk sheet should keep 0.050 cadence")
	_expect(bool(smasher_directional.get("boss_has_hit_sprite", false)), "boss attack sheet should enable boss hit sprite")

	var boss_attack_4x4_texture: Texture2D = _make_texture_size(512, 512)
	var boss_4x4_attack: Dictionary = builder.build_context({
		"boss_sprite_sheet": texture,
		"boss_attack_sheet": boss_attack_4x4_texture,
	}, "smasher")
	_expect(bool(boss_4x4_attack.get("boss_has_hit_sprite", false)), "4x4 boss attack sheet should enable boss hit sprite")
	_expect(int(boss_4x4_attack.get("boss_hit_frame_count", 0)) == 16, "4x4 boss attack sheet should use 16 hit frames")
	_expect_close(float(boss_4x4_attack.get("boss_hit_frame_speed", 0.0)), 0.045, "4x4 boss attack should use the 16-frame cadence")

	var boss_attack_3x3_autosprite_texture: Texture2D = _make_texture_size(768, 768)
	var boss_3x3_attack: Dictionary = builder.build_context({
		"boss_sprite_sheet": texture,
		"boss_attack_sheet": boss_attack_3x3_autosprite_texture,
	}, "smasher")
	_expect(bool(boss_3x3_attack.get("boss_has_hit_sprite", false)), "3x3 AutoSprite boss attack sheet should enable boss hit sprite")
	_expect(int(boss_3x3_attack.get("boss_hit_frame_count", 0)) == 8, "768x768 3x3 AutoSprite boss attack sheets should keep 8 hit frames")
	_expect_close(float(boss_3x3_attack.get("boss_hit_frame_speed", 0.0)), 0.075, "3x3 AutoSprite boss attack should keep the 8-frame cadence")

	var smasher_legacy: Dictionary = builder.build_context({
		"player_sprite_texture": texture,
		"player_idle_sprite_texture": texture,
		"player_attack_sheet": texture,
		"boss_sprite_sheet": texture,
		"boss_hit_sprite_sheet": texture,
	}, "unknown")
	_expect(str(smasher_legacy.get("selected_character_type", "")) == "smasher", "unknown character should normalize to Smasher")
	_expect(int(smasher_legacy.get("player_sprite_frame_count", 0)) == 6, "legacy Smasher sprite should use 6 frames")
	_expect_close(float(smasher_legacy.get("player_sprite_animation_speed", 0.0)), 0.10, "legacy Smasher sprite should keep 0.10 cadence")
	_expect(int(smasher_legacy.get("player_hit_frame_count", 0)) == 8, "legacy attack sheet should use 8 hit frames")
	_expect(not bool(smasher_legacy.get("player_hit_linear_frames", true)), "legacy attack sheet should not use linear hit frames")
	_expect_close(float(smasher_legacy.get("player_hit_anim_duration", 0.0)), 0.40, "legacy attack sheet should keep 0.40 duration")
	_expect(bool(smasher_legacy.get("boss_has_sprite", false)), "boss sprite sheet should enable boss sprite")
	_expect(int(smasher_legacy.get("boss_sprite_frame_count", 0)) == 8, "boss fallback sprite should use 8 frames")
	_expect(bool(smasher_legacy.get("boss_has_hit_sprite", false)), "legacy boss hit sheet should enable boss hit sprite")

	var viper_context: Dictionary = builder.build_context({
		"viper_player_sprite_texture": texture,
		"viper_player_idle_sprite_texture": texture,
		"player_attack_sheet": texture,
	}, "ViPeR")
	_expect(str(viper_context.get("selected_character_type", "")) == "viper", "Viper sprite context should normalize character")
	_expect(bool(viper_context.get("player_has_sprite", false)), "Viper sprite texture should enable player sprite")
	_expect(bool(viper_context.get("player_has_idle_sprite", false)), "Viper idle texture should enable idle sprite")
	_expect(not bool(viper_context.get("player_has_attack_sheet", true)), "Viper should not inherit Smasher attack sheets")
	_expect(int(viper_context.get("player_sprite_frame_count", 0)) == 8, "Viper walk should use 8 frames")
	_expect_close(float(viper_context.get("player_sprite_animation_speed", 0.0)), 0.10, "Viper walk should use 0.10 cadence (slowed for subculture wide-stride sprint)")
	_expect_close(float(viper_context.get("player_idle_animation_speed", 0.0)), 0.13, "Viper idle should keep 0.13 cadence")
	_expect(int(viper_context.get("player_hit_frame_count", 0)) == 4, "Viper effect context should keep 4 fallback hit frames")
	_expect_close(float(viper_context.get("player_hit_anim_duration", 0.0)), 0.36, "Viper effect context should keep fallback hit duration")

	var facade_context: Dictionary = BattleUpdateEffectsContext.new().build_context(
		FakeOwner.new({
			"battle_textures": {
				"viper_player_sprite_texture": texture,
				"viper_player_idle_sprite_texture": texture,
			},
			"selected_character_type": "viper",
		}),
		FakeRegistry.new()
	)
	_expect(str(facade_context.get("selected_character_type", "")) == "viper", "effects context facade should merge normalized character")
	_expect(bool(facade_context.get("player_has_sprite", false)), "effects context facade should merge sprite fields")
	_expect(int(facade_context.get("player_sprite_frame_count", 0)) == 8, "effects context facade should merge frame count")

	if _failures.is_empty():
		print("effects_sprite_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _make_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _make_texture_size(width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.001, message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
