extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const WEAPON_EXPECTATIONS := {
	"ak47": {
		"texture_key": "commando_player_ak47_fire_sheet",
		"active_key": "commando_ak47_fire_active",
		"timer_max": 40.0,
	},
	"bazooka": {
		"texture_key": "commando_player_bazooka_fire_sheet",
		"active_key": "commando_bazooka_fire_active",
		"timer_max": 60.0,
	},
	"net_gun": {
		"texture_key": "commando_player_net_gun_fire_sheet",
		"active_key": "commando_net_gun_fire_active",
		"timer_max": 40.0,
	},
	"bowling_trap": {
		"texture_key": "commando_player_bowling_trap_place_sheet",
		"active_key": "commando_bowling_trap_place_active",
		"timer_max": 60.0,
	},
	"suicide_drone": {
		"texture_key": "commando_player_suicide_drone_control_sheet",
		"active_key": "commando_suicide_drone_control_active",
		"timer_max": 40.0,
	},
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_weapon_fire_textures_load()
	_verify_weapon_fire_visual_scale()
	_verify_actor_context_for_each_weapon()
	_verify_weapon_fire_flip_follows_movement_direction()
	_verify_suicide_drone_fire_flip_follows_drone_side()
	_verify_frame_region_mapping()
	_verify_pistol_fire_mutex()
	_verify_non_commando_skips_weapon_fire()

	if _failures.is_empty():
		print("commando_weapon_fire_sheet_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_weapon_fire_textures_load() -> void:
	var textures: Dictionary = _load_commando_textures()
	for weapon_id in WEAPON_EXPECTATIONS.keys():
		var expectation: Dictionary = WEAPON_EXPECTATIONS[weapon_id]
		var key: String = String(expectation["texture_key"])
		var texture: Variant = textures.get(key, null)
		_expect(texture is Texture2D, "%s texture must load as Texture2D" % key)
		if texture is Texture2D:
			var typed: Texture2D = texture
			_expect(typed.get_width() == 640, "%s width must be 640" % key)
			_expect(typed.get_height() == 320, "%s height must be 320" % key)


func _verify_weapon_fire_visual_scale() -> void:
	# The five new weapon sheets were initially authored with a ~145 px body
	# inside a 160 px cell, which made Commando pop to almost double size
	# compared with idle/pistol (~97-100 px body). Lock the post-fit scale
	# so future regenerated sheets cannot silently reintroduce that jump.
	var textures: Dictionary = _load_commando_textures()
	for weapon_id in WEAPON_EXPECTATIONS.keys():
		var key: String = String(WEAPON_EXPECTATIONS[weapon_id]["texture_key"])
		var texture: Variant = textures.get(key, null)
		if not (texture is Texture2D):
			continue
		var image: Image = texture.get_image()
		_expect(image != null, "%s image must be readable for scale smoke" % key)
		if image == null:
			continue
		var heights: Array[int] = []
		for frame in range(8):
			var col: int = frame % 4
			@warning_ignore("integer_division")
			var row: int = int(frame / 4)
			var height: int = _get_solid_alpha_height(image, col * 160, row * 160, 160, 160)
			if height > 0:
				heights.append(height)
		_expect(not heights.is_empty(), "%s must have visible alpha in all frames" % key)
		if heights.is_empty():
			continue
		var total := 0.0
		var max_height := 0
		for height in heights:
			total += float(height)
			max_height = max(max_height, height)
		var avg_height: float = total / float(heights.size())
		_expect(
			avg_height >= 90.0 and avg_height <= 110.0,
			"%s average visible body height must stay near idle scale (got %.1f)" % [key, avg_height]
		)
		_expect(
			max_height <= 116,
			"%s max frame body height must not pop oversized (got %d)" % [key, max_height]
		)


func _verify_actor_context_for_each_weapon() -> void:
	for weapon_id in WEAPON_EXPECTATIONS.keys():
		var expectation: Dictionary = WEAPON_EXPECTATIONS[weapon_id]
		var ctx: Dictionary = _build_actor_context("soldier", weapon_id, float(expectation["timer_max"]), false)
		_expect(bool(ctx.get("commando_weapon_fire_active", false)), "%s weapon fire must be active" % weapon_id)
		_expect(String(ctx.get("commando_weapon_fire_id", "")) == String(weapon_id), "%s weapon fire id mismatch" % weapon_id)
		_expect(ctx.get("commando_weapon_fire_sheet", null) is Texture2D, "%s weapon fire sheet must resolve" % weapon_id)
		_expect(int(ctx.get("commando_weapon_fire_frame", -1)) == 0, "%s initial frame must be F0" % weapon_id)
		_expect(bool(ctx.get(String(expectation["active_key"]), false)), "%s specific active flag must be true" % weapon_id)
		for other_weapon_id in WEAPON_EXPECTATIONS.keys():
			if other_weapon_id == weapon_id:
				continue
			var other_expectation: Dictionary = WEAPON_EXPECTATIONS[other_weapon_id]
			_expect(
				not bool(ctx.get(String(other_expectation["active_key"]), false)),
				"%s active must exclude %s" % [weapon_id, other_weapon_id]
			)


func _verify_weapon_fire_flip_follows_movement_direction() -> void:
	var left_ctx: Dictionary = _build_actor_context("soldier", "ak47", 40.0, false, -3.0)
	_expect(bool(left_ctx.get("commando_weapon_fire_flip_h", false)), "Commando weapon fire sheet must flip while firing during left movement")
	var right_ctx: Dictionary = _build_actor_context("soldier", "ak47", 40.0, false, 3.0)
	_expect(not bool(right_ctx.get("commando_weapon_fire_flip_h", true)), "Commando weapon fire sheet must stay unflipped while firing during right movement")


func _verify_suicide_drone_fire_flip_follows_drone_side() -> void:
	var left_drone_ctx: Dictionary = _build_actor_context("soldier", "suicide_drone", 40.0, false, 3.0, Vector2(260.0, 620.0), true)
	_expect(bool(left_drone_ctx.get("commando_weapon_fire_flip_h", false)), "Suicide-drone control sheet should flip when the drone is left of the player")
	var right_drone_ctx: Dictionary = _build_actor_context("soldier", "suicide_drone", 40.0, false, -3.0, Vector2(440.0, 620.0), true)
	_expect(not bool(right_drone_ctx.get("commando_weapon_fire_flip_h", true)), "Suicide-drone control sheet should keep the right-facing sheet when the drone is right of the player")


func _verify_frame_region_mapping() -> void:
	var textures: Dictionary = _load_commando_textures()
	var renderer := Stage1PlayerSpriteRenderer.new()
	var texture: Texture2D = textures["commando_player_ak47_fire_sheet"]
	for frame in range(8):
		var ctx := {
			"commando_weapon_fire_grid_cols": 4,
			"commando_weapon_fire_grid_rows": 2,
			"commando_weapon_fire_frame_count": 8,
			"commando_weapon_fire_frame": frame,
		}
		var region: Rect2 = renderer._get_commando_weapon_fire_sprite_region(ctx, texture)
		var expected_col: int = frame % 4
		@warning_ignore("integer_division")
		var expected_row: int = int(frame / 4)
		_expect_rect(
			region,
			Rect2(Vector2(expected_col * 160.0, expected_row * 160.0), Vector2(160.0, 160.0)),
			"weapon fire frame %d region" % frame
		)


func _verify_pistol_fire_mutex() -> void:
	var ctx: Dictionary = _build_actor_context("soldier", "ak47", 40.0, true)
	_expect(bool(ctx.get("commando_weapon_fire_active", false)), "AK-47 fire must stay active when pistol timer is also present")
	_expect(not bool(ctx.get("commando_pistol_fire_active", true)), "Pistol fire must be suppressed by non-pistol weapon fire")


func _verify_non_commando_skips_weapon_fire() -> void:
	var ctx: Dictionary = _build_actor_context("smasher", "ak47", 40.0, false)
	_expect(not bool(ctx.get("commando_weapon_fire_active", false)), "Non-commando must not emit weapon fire active")
	_expect(ctx.get("commando_weapon_fire_sheet", null) == null, "Non-commando must not emit weapon fire sheet")


func _build_actor_context(
	character_type: String,
	weapon_id: String,
	timer_max: float,
	pistol_also_active: bool,
	player_speed: float = 0.0,
	drone_pos: Vector2 = Vector2.ZERO,
	drone_active: bool = false
) -> Dictionary:
	var textures: Dictionary = _load_commando_textures()
	var draw_builder := BattleDrawActorContext.new()
	return draw_builder.build({
		"selected_character_type": character_type,
		"textures": textures,
		"player_speed": player_speed,
		"player_pos": Vector2(320.0, 650.0),
		"player_paddle_size": Vector2(100.0, 50.0),
	}, {
		"commando_weapon_controller": FakeWeaponController.new(weapon_id),
		"commando_firearm_runtime": FakeFirearmRuntime.new(weapon_id, timer_max, pistol_also_active, drone_pos, drone_active),
	})


func _load_commando_textures() -> Dictionary:
	var resources := BattleResources.new()
	return resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if (
		abs(actual.position.x - expected.position.x) > 0.001
		or abs(actual.position.y - expected.position.y) > 0.001
		or abs(actual.size.x - expected.size.x) > 0.001
		or abs(actual.size.y - expected.size.y) > 0.001
	):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _get_solid_alpha_height(image: Image, start_x: int, start_y: int, width: int, height: int) -> int:
	var first_y := -1
	var last_y := -1
	for y in range(height):
		var row_mass := 0
		for x in range(width):
			if image.get_pixel(start_x + x, start_y + y).a > 0.62:
				row_mass += 1
		if row_mass > 12:
			if first_y < 0:
				first_y = y
			last_y = y
	if first_y < 0 or last_y < first_y:
		return 0
	return last_y - first_y + 1


class FakeWeaponController extends RefCounted:
	var current_weapon_id: String

	func _init(weapon_id: String) -> void:
		current_weapon_id = weapon_id


class FakeFirearmRuntime extends RefCounted:
	var weapon_id: String
	var timer_max: float
	var pistol_also_active: bool
	var drone_pos: Vector2
	var drone_active: bool

	func _init(
		p_weapon_id: String,
		p_timer_max: float,
		p_pistol_also_active: bool,
		p_drone_pos: Vector2 = Vector2.ZERO,
		p_drone_active: bool = false
	) -> void:
		weapon_id = p_weapon_id
		timer_max = p_timer_max
		pistol_also_active = p_pistol_also_active
		drone_pos = p_drone_pos
		drone_active = p_drone_active

	func get_actor_draw_context() -> Dictionary:
		return {
			"commando_firearm_weapon_fire_sheet_state": {
				"active": true,
				"weapon_id": weapon_id,
				"timer_frames": timer_max,
				"timer_max_frames": timer_max,
				"frame_count": 8,
			},
			"commando_firearm_pistol_state": {
				"fire_delay_frames": 24.0 if pistol_also_active else 0.0,
				"fire_delay_max_frames": 24.0,
				"post_fire_animation_frames": 0.0,
				"post_fire_animation_max_frames": 18.0,
				"animation_active": pistol_also_active,
			},
			"commando_firearm_suicide_drone_state": {
				"active": drone_active,
				"pos": drone_pos,
				"velocity": Vector2.ZERO,
				"grace_frames": 0.0,
			},
		}
