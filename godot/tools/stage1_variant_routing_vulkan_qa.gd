extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const Stage1ActorRenderer := preload("res://scripts/stages/stage1/stage1_actor_renderer.gd")
const Stage1DaljiBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage1DaljiBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const Stage1DaljiSpinningTopSkillState := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_skill_state.gd")
const Stage1GaksitalBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_cooldown_state.gd")
const Stage1GaksitalBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_renderer.gd")
const Stage1GaksitalFanThrowSkillState := preload("res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd")
const Stage1PododaejangArrestRopeSkillState := preload("res://scripts/stages/stage1/stage1_pododaejang_arrest_rope_skill_state.gd")
const Stage1PododaejangBossSkillCooldownState := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_cooldown_state.gd")
const Stage1PododaejangBossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_renderer.gd")
const Stage1PododaejangPatrolGuardsSkillState := preload("res://scripts/stages/stage1/stage1_pododaejang_patrol_guards_skill_state.gd")
const TowerAscentBossRegistry := preload("res://scripts/tower_ascent/tower_ascent_boss_registry.gd")

const VIEW_SIZE := Vector2i(1280, 750)
const GAME_OFFSET := Vector2(260.0, 0.0)
const GAME_SIZE := Vector2(760.0, 750.0)
const OUTPUT_DIR := "res://.godot/codex_captures/stage1_variant_boss_routing"
const SCREEN_BACKGROUND := Color("17120f")


class CaptureCanvas:
	extends Node2D

	var actor_renderer: Object = Stage1ActorRenderer.new()
	var header_renderer: Object = ScoreboardOverlayHeaderRenderer.new()
	var hud_renderer: Object
	var draw_context: Dictionary = {}
	var hud_context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), SCREEN_BACKGROUND, true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(260.0, 750.0)), Color("261c17"), true)
		draw_rect(Rect2(Vector2(1020.0, 0.0), Vector2(260.0, 750.0)), Color("261c17"), true)
		draw_set_transform(GAME_OFFSET)
		actor_renderer.draw(self, draw_context)
		actor_renderer.draw_spinning_top(self, draw_context)
		draw_set_transform(Vector2.ZERO)
		if hud_renderer != null:
			hud_renderer.draw(self, hud_context)
		header_renderer.draw(
			self,
			Rect2(300.0, 6.0, 680.0, 60.0),
			0.96,
			"",
			1,
			draw_context
		)


var _canvas: CaptureCanvas
var _variant := ""
var _expected_name := ""
var _floor_one_second_encounter := false
var _floor_one_map_seed := 0
var _floor_one_opening_variant := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage1_variant_routing_vulkan_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage1_variant_routing_vulkan_qa requires a Vulkan rendering device")
		return
	_variant = _get_variant_argument()
	if _variant not in ["dalji", "gaksi", "podo"]:
		_fail("unsupported Stage 1 visual QA variant: %s" % _variant)
		return
	_floor_one_second_encounter = OS.get_environment(
		"STAGE1_QA_FLOOR_ONE_SECOND_ENCOUNTER"
	) == "1"
	if _floor_one_second_encounter and not _resolve_floor_one_second_encounter():
		_fail("could not resolve %s as a seeded second Floor 1 encounter" % _variant)
		return
	_expected_name = {"dalji": "달지", "gaksi": "각시탈", "podo": "포도대장"}[_variant]
	get_root().size = VIEW_SIZE
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create Stage 1 variant visual QA output directory")
		return

	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"current_stage": 1,
		"stage1_boss_variant": _variant,
		"selected_character_type": "smasher",
		"include_all_stages": false,
		"include_all_characters": false,
		"include_result_sheets": false,
	})
	var fixture: Dictionary = _build_fixture(_variant, textures)
	_canvas = CaptureCanvas.new()
	_canvas.draw_context = fixture.get("draw_context", {})
	_canvas.hud_context = fixture.get("hud_context", {})
	_canvas.hud_renderer = fixture.get("hud_renderer", null)
	get_root().add_child(_canvas)
	_canvas.queue_redraw()
	for _frame_index in range(10):
		await process_frame

	if _canvas.draw_count <= 0:
		_fail("Stage 1 variant QA canvas never received a draw callback")
		return
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("Stage 1 variant QA did not capture an exact 1280x750 window image")
		return
	var output_name := "stage1_%s_combat.png" % _variant
	if _floor_one_second_encounter:
		output_name = "floor_one_second_encounter_%s.png" % _variant
	var output_path := OUTPUT_DIR.path_join(output_name)
	if image.save_png(output_path) != OK:
		_fail("Stage 1 variant QA failed to save %s" % output_path)
		return
	var central_pixels := _count_pixels_different_from(image, Rect2i(260, 0, 760, 750), SCREEN_BACKGROUND)
	var left_hud_pixels := _count_bright_pixels(image, Rect2i(0, 80, 260, 610))
	if central_pixels < 90000:
		_fail("Stage 1 %s capture lacks a production playfield/actor surface" % _variant)
		return
	if left_hud_pixels < 120:
		_fail("Stage 1 %s capture lacks a visible boss skill HUD" % _variant)
		return
	var resolved_name: String = _canvas.header_renderer.resolve_boss_name(_canvas.draw_context)
	if resolved_name != _expected_name:
		_fail("Stage 1 %s scoreboard name resolved as %s" % [_variant, resolved_name])
		return
	print("[Stage1VariantRoutingVulkanQA] variant=%s name=%s central_pixels=%d left_hud_pixels=%d sha256=%s evidence=%s" % [
		_variant,
		_expected_name,
		central_pixels,
		left_hud_pixels,
		FileAccess.get_sha256(ProjectSettings.globalize_path(output_path)),
		output_path,
	])
	if _floor_one_second_encounter:
		print("[Stage1VariantRoutingVulkanQA] floor_one_map_seed=%d opening_variant=%s second_variant=%s" % [
			_floor_one_map_seed,
			_floor_one_opening_variant,
			_variant,
		])
	print("stage1_variant_routing_vulkan_qa: ok")
	quit(0)


func _build_fixture(variant: String, textures: Dictionary) -> Dictionary:
	var context := {
		"current_stage": 1,
		"stage1_boss_variant": variant,
		"stage_boss_variant": "",
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_pos": Vector2(330.0, 105.0),
		"boss_draw_pos": Vector2(330.0, 105.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"boss_visual_center_y_offset": 30.0 if variant == "podo" else 25.0,
		"boss_sprite_draw_size": Vector2(115.2, 134.4) if variant == "podo" else Vector2(96.0, 112.0),
		"boss_idle_frame": 3,
		"boss_sprite_frame": 3,
		"boss_is_walking": false,
		"boss_facing_direction": 1,
		"player_pos": Vector2(302.0, 655.0),
		"player_draw_pos": Vector2(302.0, 655.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_active": true,
		"ball_pos": Vector2(380.0, 405.0),
		"ball_vel": Vector2(3.0, 5.0),
		"ball_size": 28.6,
		"time_seconds": 2.25,
		"shake_offset": Vector2.ZERO,
	}
	context.merge(textures, true)
	var hud_state: Object
	var hud_renderer: Object
	if variant == "dalji":
		var tops := Stage1DaljiSpinningTopSkillState.new()
		if not tops.activate(context):
			_fail("Dalji visual QA could not activate spinning tops")
			return {}
		tops.update_and_collide(18.0, {}, context)
		context.merge(tops.get_draw_context(), true)
		hud_state = Stage1DaljiBossSkillCooldownState.new()
		hud_renderer = Stage1DaljiBossSkillHudRenderer.new()
	elif variant == "gaksi":
		var fans := Stage1GaksitalFanThrowSkillState.new()
		if not fans.activate(context):
			_fail("Gaksital visual QA could not activate fan throw")
			return {}
		fans.update_and_collide(30.0, {}, context)
		fans.update_and_collide(20.0, {}, context)
		context.merge(fans.get_draw_context(), true)
		hud_state = Stage1GaksitalBossSkillCooldownState.new()
		hud_renderer = Stage1GaksitalBossSkillHudRenderer.new()
	else:
		var guards := Stage1PododaejangPatrolGuardsSkillState.new()
		var rope := Stage1PododaejangArrestRopeSkillState.new()
		guards.set_rng_seed_for_test(4417)
		if not guards.activate(context) or not rope.activate_for_test(context):
			_fail("Pododaejang visual QA could not activate both combat skills")
			return {}
		guards.update_and_collide(18.0, {}, context)
		rope.update(18.0, context)
		context.merge(guards.get_draw_context(), true)
		context.merge(rope.get_draw_context(), true)
		hud_state = Stage1PododaejangBossSkillCooldownState.new()
		hud_renderer = Stage1PododaejangBossSkillHudRenderer.new()
	if hud_renderer != null and hud_renderer.has_method("prewarm_assets"):
		hud_renderer.prewarm_assets()
	var hud_context: Dictionary = hud_state.get_hud_context()
	hud_context.merge({
		"view_size": Vector2(VIEW_SIZE),
		"game_offset": GAME_OFFSET,
		"game_size": GAME_SIZE,
		"time_seconds": 2.25,
		"commando_firearm_panel_rect": Rect2(),
	}, true)
	return {
		"draw_context": context,
		"hud_context": hud_context,
		"hud_renderer": hud_renderer,
	}


func _count_pixels_different_from(image: Image, rect: Rect2i, background: Color) -> int:
	var count := 0
	for y in range(rect.position.y, mini(rect.end.y, image.get_height()), 2):
		for x in range(rect.position.x, mini(rect.end.x, image.get_width()), 2):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b) > 0.08:
				count += 1
	return count


func _count_bright_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, mini(rect.end.y, image.get_height()), 2):
		for x in range(rect.position.x, mini(rect.end.x, image.get_width()), 2):
			var pixel := image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.45:
				count += 1
	return count


func _get_variant_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--stage1-variant="):
			return value.trim_prefix("--stage1-variant=").strip_edges().to_lower()
	return ""


func _resolve_floor_one_second_encounter() -> bool:
	var registry := TowerAscentBossRegistry.new()
	for map_seed in range(1, 4097):
		var slots: Array[Dictionary] = registry.get_seeded_floor_slots(1, map_seed)
		if slots.size() < 2:
			continue
		var opening_variant := str(slots[0].get("variant", ""))
		var second_variant := str(slots[1].get("variant", ""))
		if second_variant != _variant or opening_variant == _variant:
			continue
		_floor_one_map_seed = map_seed
		_floor_one_opening_variant = opening_variant
		return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
