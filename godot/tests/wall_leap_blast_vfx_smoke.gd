extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const VIEW_SIZE := Vector2i(760, 250)
const DRAW_OFFSET := Vector2(0.0, 72.0)

var _support := Support.new()
var _failures: Array[String] = []


class BlastCanvas:
	extends Node2D
	var wall_leap_state: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.02, 0.03, 0.06), true)
		draw_set_transform(DRAW_OFFSET)
		wall_leap_state.draw_effects(self, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = _make_committed_blast_fixture(50.0)
	var runtime: Object = fixture["runtime"]
	var wall_state: Object = runtime.wall_leap_state
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("wall_leap_raid_blast_vfx_active", false)), "RMB commit must start the blast presentation")
	_expect(bool(snapshot.get("wall_leap_raid_blast_vfx_hit", false)), "aligned blast presentation must retain its hit accent")
	_expect(snapshot.get("wall_leap_raid_blast_vfx_origin", Vector2.ZERO) != Vector2.ZERO, "blast presentation must retain a world-space origin")
	_expect(runtime.has_visible_effects(), "active blast must keep the Viper draw fanout open")
	var shakes: Array[Vector2] = fixture["feedback"].shakes
	_expect(shakes.size() == 1, "blast commit must trigger exactly one impact shake")
	if shakes.size() == 1:
		_expect(shakes[0].is_equal_approx(Vector2(0.12, 7.0)), "aligned blast must use the authored 0.12s / 7.0 impact shake")

	wall_state.prewarm_assets()
	if DisplayServer.get_name().to_lower().find("headless") < 0:
		await _verify_rendered_layers(wall_state)

	_support.advance_frames(fixture, 14)
	snapshot = runtime.get_snapshot()
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "idle", "blast fixture must finish the return before testing its detached tail")
	_expect(bool(snapshot.get("wall_leap_raid_blast_vfx_active", false)), "blast afterglow must survive the return landing")
	_expect(runtime.has_visible_effects(), "detached afterglow must keep the production visibility query open")

	_support.advance_frames(fixture, 16)
	snapshot = runtime.get_snapshot()
	_expect(not bool(snapshot.get("wall_leap_raid_blast_vfx_active", true)), "blast afterglow must self-clear after its bounded lifetime")
	_expect(not runtime.has_visible_effects(), "visibility query must close after the detached blast tail expires")

	var miss_fixture: Dictionary = _make_committed_blast_fixture(51.0)
	var miss_snapshot: Dictionary = miss_fixture["runtime"].get_snapshot()
	_expect(bool(miss_snapshot.get("wall_leap_raid_blast_vfx_active", false)), "a range miss must still render the committed explosion")
	_expect(not bool(miss_snapshot.get("wall_leap_raid_blast_vfx_hit", true)), "a range miss must not render the boss hit accent")
	var miss_shakes: Array[Vector2] = miss_fixture["feedback"].shakes
	_expect(miss_shakes.size() == 1 and miss_shakes[0].is_equal_approx(Vector2(0.12, 5.2)), "a range miss must retain the lighter explosion shake")
	miss_fixture["runtime"].reset()
	miss_snapshot = miss_fixture["runtime"].get_snapshot()
	_expect(not bool(miss_snapshot.get("wall_leap_raid_blast_vfx_active", true)), "runtime reset must tear down an active blast presentation")
	_expect(not miss_fixture["runtime"].has_visible_effects(), "runtime reset must close the blast draw fanout")
	_finish()


func _make_committed_blast_fixture(offset: float) -> Dictionary:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.advance_frames(fixture, 16)
	var player_center_x: float = (fixture["player_pos"] as Vector2).x + 77.5
	fixture["context"]["boss_pos"] = Vector2(player_center_x + offset - 50.0, 25.0)
	_support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	var fuse_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(fuse_snapshot.get("wall_leap_raid_state", "")) == "fuse", "production RMB route must arm FUSE before the visual commit")
	_expect(fuse_snapshot.get("wall_leap_raid_fuse_visual_center", Vector2.ZERO) != Vector2.ZERO, "FUSE must expose the collapsing-ring telegraph center")
	_support.advance_frames(fixture, 43)
	return fixture


func _verify_rendered_layers(wall_state: Object) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := BlastCanvas.new()
	canvas.wall_leap_state = wall_state
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "blast VFX seal must render through a real CanvasItem")
	if image != null and not image.is_empty():
		var luminous_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.b > 0.30 and color.g > 0.18 and color.r > 0.10:
					luminous_pixels += 1
		_expect(luminous_pixels > 1400, "blast VFX must draw a substantial core, shockwave, ray, and sparkle footprint")
	viewport.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("wall_leap_blast_vfx_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
