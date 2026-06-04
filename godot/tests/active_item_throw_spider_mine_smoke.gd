extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemThrowSpiderMine := preload("res://scripts/items/active_item_throw_spider_mine.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_grenade_explosion() -> void:
		calls.append("play_grenade_explosion")

	func play_spider_mine_setup() -> void:
		calls.append("play_spider_mine_setup")

	func sync_spider_mine_walk_loop(active: bool) -> void:
		calls.append("sync_walk:%s" % str(active))


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "battle_feedback_state":
			return feedback
		return null


func _init() -> void:
	_verify_helper_deploys_spider_mine()
	_verify_controller_windup_release_delegates_spider_mine()
	_verify_mine_state_updates_and_walk_audio()
	_verify_boss_explosion_applies_effects()
	_verify_particles_and_slow_decay()
	_verify_renderer_uses_spider_mine_sheets()

	if _failures.is_empty():
		print("active_item_throw_spider_mine_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_deploys_spider_mine() -> void:
	var helper: Object = ActiveItemThrowSpiderMine.new()
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()

	helper.deploy_mine(controller, owner)

	_expect(controller.get_spider_mines().size() == 1, "spider mine helper should append one mine")
	var mine: Dictionary = controller.get_spider_mines()[0]
	_expect(str(mine.get("state", "")) == "spawn", "spider mine helper should start in spawn state")
	_expect(str(mine.get("side", "")) == "left", "spider mine helper should choose player side")
	_expect(_get_vector2(mine, "position") == Vector2(264.0, 719.0), "spider mine helper should preserve legacy spawn position")
	_expect(is_equal_approx(float(mine.get("wall_x", 0.0)), 31.0), "spider mine helper should preserve wall target")
	_expect(is_equal_approx(float(mine.get("corner_y", 0.0)), 50.0), "spider mine helper should preserve corner target")
	_expect(is_equal_approx(float(mine.get("boss_width", 0.0)), 100.0), "spider mine helper should store boss width")


func _verify_controller_windup_release_delegates_spider_mine() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "spider_mine",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(300.0, 680.0),
		"target_position": Vector2(330.0, 45.0),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), registry)

	_expect(controller.get_pending_throws().is_empty(), "spider mine windup release should clear pending queue")
	_expect(controller.get_spider_mines().size() == 1, "spider mine windup release should deploy one mine")
	_expect(registry.audio.calls == ["play_throw"], "spider mine windup release should play throw audio")


func _verify_mine_state_updates_and_walk_audio() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var mines: Array[Dictionary] = [{
		"position": Vector2(40.0, 719.0),
		"wall_x": 31.0,
		"floor_y": 719.0,
		"corner_y": 50.0,
		"state": "floor",
		"delay_timer": 0.0,
		"flash_timer": 0.0,
		"side": "left",
		"size": controller.SPIDER_MINE_SIZE,
		"glow_phase": 0.0,
		"armed_elapsed": 0.0,
		"step_phase": 0.0,
		"embed_timer": 0.0,
		"embed_depth": 0.0,
		"embed_slam_timer": 0.0,
		"boss_width": 100.0,
	}]
	controller.spider_mines = mines

	controller._update_spider_mines(FakeOwner.new(), registry, 1.0 / 60.0)

	_expect(str(controller.get_spider_mines()[0].get("state", "")) == "wall", "floor spider mine should reach wall when close enough")
	_expect(_get_vector2(controller.get_spider_mines()[0], "position") == Vector2(31.0, 719.0), "floor spider mine should snap to wall target")
	_expect(registry.audio.calls == ["sync_walk:true"], "walking spider mine should sync walk loop active")


func _verify_boss_explosion_applies_effects() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var mine := {
		"position": Vector2(380.0, 50.0),
		"state": "armed",
		"embed_depth": 0.0,
		"size": controller.SPIDER_MINE_SIZE,
	}

	controller._trigger_spider_mine_explosion(owner, registry, mine, "boss")

	_expect(str(mine.get("state", "")) == "exploding", "boss spider mine hit should enter exploding state")
	_expect(is_equal_approx(float(mine.get("explosion_timer", 0.0)), controller.SPIDER_MINE_EXPLOSION_DURATION_FRAMES), "spider mine explosion should start full timer")
	_expect(controller.get_spider_mine_particles().size() == controller.SPIDER_MINE_PARTICLE_COUNT, "spider mine explosion should spawn particles")
	_expect(is_equal_approx(controller.grenade_boss_stun_timer_frames, controller.SPIDER_MINE_BOSS_STUN_FRAMES), "spider mine boss hit should stun boss")
	_expect(is_equal_approx(controller.grenade_boss_knockback_vel, -controller.SPIDER_MINE_BOSS_KNOCKBACK_POWER), "spider mine boss hit should apply legacy knockback direction")
	_expect(is_equal_approx(controller.spider_mine_slow_timer_frames, controller.SPIDER_MINE_SLOW_DURATION_FRAMES), "spider mine boss hit should apply slow timer")
	_expect(registry.feedback.shakes == [Vector2(0.18, 5.0)], "boss spider mine hit should request boss impact shake")
	_expect(registry.audio.calls == ["play_grenade_explosion"], "boss spider mine hit should play explosion audio")


func _verify_particles_and_slow_decay() -> void:
	var controller: Object = ActiveItemThrowController.new()
	controller._spawn_spider_mine_particles(Vector2(380.0, 50.0))
	var first_particle: Dictionary = controller.get_spider_mine_particles()[0]
	var first_life: float = float(first_particle.get("life_frames", 0.0))

	controller._update_spider_mine_particles(1.0 / 60.0)

	_expect(controller.get_spider_mine_particles().size() == controller.SPIDER_MINE_PARTICLE_COUNT, "fresh spider mine particles should remain after one frame")
	_expect(float(controller.get_spider_mine_particles()[0].get("life_frames", 0.0)) < first_life, "spider mine particles should age")

	controller.spider_mine_slow_timer_frames = 2.0
	controller.spider_mine_slow_text_timer_frames = 2.0
	controller._update_spider_mine_slow(1.0 / 60.0)

	_expect(is_equal_approx(controller.spider_mine_slow_timer_frames, 1.0), "spider mine slow timer should decay by one frame")
	_expect(is_equal_approx(controller.spider_mine_slow_text_timer_frames, 1.0), "spider mine slow text timer should decay by one frame")


func _verify_renderer_uses_spider_mine_sheets() -> void:
	var spider_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_spider_mine_renderer.gd")
	var throw_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	_expect(spider_source.find("func prewarm_assets_step()") >= 0, "spider mine renderer should expose staged sheet prewarm")
	_expect(throw_source.find("_spider_mine_renderer.prewarm_assets_step()") >= 0, "throw renderer should advance spider mine sheets through staged prewarm")
	var renderer := ActiveItemThrowRenderer.new()
	renderer.prewarm_assets()
	var status: Dictionary = renderer.get_spider_mine_asset_status()
	_expect(bool(status.get("crawl_sheet_loaded", false)), "spider mine crawl sheet should prewarm")
	_expect(bool(status.get("installed_idle_sheet_loaded", false)), "spider mine installed idle sheet should prewarm")
	_expect(bool(status.get("deploy_sheet_loaded", false)), "spider mine deploy sheet should prewarm")
	_expect(int(status.get("sheet_columns", 0)) == 4, "spider mine sheets should use a 4-column grid")
	_expect(int(status.get("sheet_frame_count", 0)) == 16, "spider mine sheets should expose sixteen frames")
	_expect(is_equal_approx(float(status.get("sheet_draw_size", 0.0)), 44.0), "spider mine sheet draw size should stay compact")
	_verify_alpha_png_asset(str(status.get("crawl_sheet_path", "")), Vector2i(2048, 2048), "spider mine crawl sheet")
	_verify_alpha_png_asset(str(status.get("installed_idle_sheet_path", "")), Vector2i(2048, 2048), "spider mine installed idle sheet")
	_verify_alpha_png_asset(str(status.get("deploy_sheet_path", "")), Vector2i(2048, 2048), "spider mine deploy sheet")
	_expect(renderer._get_spider_mine_sheet_texture_for_state("spawn") == renderer._get_spider_mine_deploy_sheet_texture(), "spawn spider mines should use the deploy sheet")
	_expect(renderer._get_spider_mine_sheet_texture_for_state("floor") == renderer._get_spider_mine_crawl_sheet_texture(), "floor spider mines should use the crawl sheet")
	_expect(renderer._get_spider_mine_sheet_texture_for_state("wall") == renderer._get_spider_mine_crawl_sheet_texture(), "wall spider mines should use the crawl sheet")
	_expect(renderer._get_spider_mine_sheet_texture_for_state("armed") == renderer._get_spider_mine_installed_idle_sheet_texture(), "armed spider mines should use the installed idle sheet")
	_expect(renderer._get_spider_mine_sheet_frame({"delay_timer": 60.0}, "spawn") == 0, "fresh spawn spider mine should start at deploy frame 0")
	_expect(renderer._get_spider_mine_sheet_frame({"delay_timer": 0.0}, "spawn") == 15, "finished spawn delay should reach the final deploy frame")
	_expect(is_equal_approx(renderer._get_spider_mine_sheet_angle_degrees({"side": "left"}, "wall"), 90.0), "left-wall spider mines should point their legs into the left wall")
	_expect(is_equal_approx(renderer._get_spider_mine_sheet_angle_degrees({"side": "right"}, "wall"), -90.0), "right-wall spider mines should point their legs into the right wall")
	_expect(is_equal_approx(renderer._get_spider_mine_sheet_angle_degrees({"side": "left"}, "embedding"), 90.0), "embedding spider mines should keep their left-wall leg contact")
	_expect(is_equal_approx(renderer._get_spider_mine_sheet_angle_degrees({"side": "right"}, "armed"), -90.0), "armed spider mines should keep their right-wall leg contact")
	_expect(is_equal_approx(renderer._get_spider_mine_sheet_angle_degrees({"side": "left"}, "floor"), 0.0), "floor spider mines should remain upright before reaching a wall")
	_expect(renderer._get_spider_mine_render_center(Vector2(31.0, 50.0), {"side": "left"}, "wall") == Vector2(13.0, 50.0), "left-wall spider mines should visually tuck into the wall")
	_expect(renderer._get_spider_mine_render_center(Vector2(729.0, 50.0), {"side": "right"}, "wall") == Vector2(747.0, 50.0), "right-wall spider mines should visually tuck into the wall")
	_expect(renderer._get_spider_mine_render_center(Vector2(31.0, 719.0), {"side": "left"}, "floor") == Vector2(31.0, 719.0), "floor spider mines should not tuck before reaching a wall")
	var crawl_source: Rect2 = renderer._get_spider_mine_sheet_source_rect(renderer._get_spider_mine_crawl_sheet_texture(), 15)
	_expect(crawl_source.position == Vector2(1536.0, 1536.0), "spider mine frame 15 should resolve to the bottom-right 4x4 cell")
	_expect(crawl_source.size == Vector2(512.0, 512.0), "spider mine 2048 sheet cells should be 512x512")


func _verify_alpha_png_asset(path: String, expected_size: Vector2i, label: String) -> void:
	_expect(FileAccess.file_exists(path), "%s PNG should exist" % label)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s PNG should load as an image" % label)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should keep expected size %s" % [label, str(expected_size)])
	var size: Vector2i = image.get_size()
	var corner_alpha := [
		image.get_pixel(0, 0).a,
		image.get_pixel(size.x - 1, 0).a,
		image.get_pixel(0, size.y - 1).a,
		image.get_pixel(size.x - 1, size.y - 1).a,
	]
	for alpha in corner_alpha:
		_expect(alpha <= 0.01, "%s corners should stay transparent" % label)


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
