extends SceneTree

const Support := preload("res://tests/wall_leap_test_support.gd")

const VIEW_SIZE := Vector2i(760, 250)
const DRAW_OFFSET := Vector2(0.0, 72.0)
const WINDOWED_CAPTURE_PATH := "res://.godot/codex_logs/wall_leap_rev9_blast_windowed.png"
const FUSE_CAPTURE_PATH := "res://.godot/codex_logs/wall_leap_rev10_fuse_windowed.png"
const LATE_SHARDS_CAPTURE_PATH := "res://.godot/codex_logs/wall_leap_rev10_late_shards_windowed.png"
const SMOKE_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_smoke_bloom_imagegen_v1.png"
const SHARDS_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_blade_shards_imagegen_v1.png"
const RING_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_shock_ring_imagegen_v1.png"
const POWDER_CHARGE_PATH := "res://assets/sprites/characters/viper/wall_leap_raid/serin_blast_powder_charge_imagegen_v1.png"
const BACKGROUND_COLOR := Color(0.02, 0.03, 0.06)

var _support := Support.new()
var _failures: Array[String] = []


class BlastCanvas:
	extends Node2D
	var wall_leap_state: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND_COLOR, true)
		draw_set_transform(DRAW_OFFSET)
		wall_leap_state.draw_effects(self, Vector2.ZERO, {
			"game_offset": DRAW_OFFSET,
			"render_scale": 1.0,
		})
		draw_set_transform(Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = _make_committed_blast_fixture(50.0)
	var runtime: Object = fixture["runtime"]
	var wall_state: Object = runtime.wall_leap_state
	_verify_source_contract()
	_verify_texture_alpha_contract(SMOKE_PATH, Vector2i(1024, 1024))
	_verify_texture_alpha_contract(SHARDS_PATH, Vector2i(512, 512))
	_verify_texture_alpha_contract(RING_PATH, Vector2i(1024, 1024))
	_verify_texture_alpha_contract(POWDER_CHARGE_PATH, Vector2i(512, 512))
	var pipeline: Dictionary = wall_state.get_blast_vfx_pipeline_status()
	_expect(int(pipeline.get("wall_leap_blast_texture_layer_count", 0)) == 3, "Serin blast must expose exactly three authored texture pieces")
	_expect(int(pipeline.get("wall_leap_fx_texture_layer_count", 0)) == 4, "Serin Wall-Leap FX must add the powder charge as a fourth authored texture piece")
	_expect(str(pipeline.get("wall_leap_blast_smoke_blend_mode", "")) == "mix", "ink smoke must retain MIX blending")
	_expect(str(pipeline.get("wall_leap_blast_blade_shards_blend_mode", "")) == "add", "blade shards must use ADD blending")
	_expect(str(pipeline.get("wall_leap_blast_shock_ring_blend_mode", "")) == "add", "shock ring must use ADD blending")
	_expect(str(pipeline.get("wall_leap_fuse_powder_charge_blend_mode", "")) == "mix", "solid powder charge must use MIX rather than disappearing under ADD")
	_expect(str(pipeline.get("wall_leap_fuse_powder_charge_texture_path", "")) == POWDER_CHARGE_PATH, "FUSE must route the dedicated powder-charge texture")
	_expect(bool(pipeline.get("wall_leap_fuse_powder_charge_texture_ready", false)), "powder charge texture must load explicitly instead of degrading into a silent blank")
	_expect(bool(pipeline.get("wall_leap_blast_texture_pieces_ready", false)), "all three dedicated Serin blast textures must load through the runtime pipeline")
	_expect(bool(pipeline.get("wall_leap_fx_texture_pieces_ready", false)), "all four Serin Wall-Leap textures must load through the runtime pipeline")
	_expect(float(pipeline.get("wall_leap_fuse_ember_visual_scale", 0.0)) >= 1.0, "FUSE ember must retain the production readability scale")
	_expect(float(pipeline.get("wall_leap_blast_shards_tail_seconds", 0.0)) > float(pipeline.get("wall_leap_blast_core_seconds", 0.0)), "blade shards must outlive the accepted smoke/ring body")
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
		await _verify_fuse_render(_make_mid_fuse_fixture())
		await _verify_rendered_layers(wall_state)
		await _verify_late_shards_render(_make_late_blast_fixture())

	_support.advance_frames(fixture, 14)
	snapshot = runtime.get_snapshot()
	_expect(str(snapshot.get("wall_leap_raid_state", "")) == "idle", "blast fixture must finish the return before testing its detached tail")
	_expect(bool(snapshot.get("wall_leap_raid_blast_vfx_active", false)), "blast afterglow must survive the return landing")
	_expect(runtime.has_visible_effects(), "detached afterglow must keep the production visibility query open")

	_support.advance_frames(fixture, 34)
	snapshot = runtime.get_snapshot()
	_expect(not bool(snapshot.get("wall_leap_raid_blast_vfx_active", true)), "blast afterglow must self-clear after its bounded lifetime")
	_expect(not runtime.has_visible_effects(), "visibility query must close after the detached blast tail expires")
	var expired_host_status: Dictionary = wall_state.get_blast_vfx_host_status()
	_expect(not bool(expired_host_status.get("smoke_visible", false)), "blast expiry must hide the detached MIX smoke layer outside the draw gate")
	_expect(not bool(expired_host_status.get("blade_shards_visible", false)), "blast expiry must hide the detached ADD shard layer outside the draw gate")
	_expect(not bool(expired_host_status.get("shock_ring_visible", false)), "blast expiry must hide the detached ADD ring layer outside the draw gate")
	_expect(not bool(expired_host_status.get("powder_charge_visible", false)), "blast expiry must hide the detached MIX powder-charge layer outside the draw gate")

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
	_expect(fuse_snapshot.get("wall_leap_raid_fuse_visual_center", Vector2.ZERO) != Vector2.ZERO, "FUSE must expose the burning-wick telegraph center")
	var fuse_start: Dictionary = fixture["runtime"].wall_leap_state.get_fuse_visual_snapshot()
	_expect(is_equal_approx(float(fuse_start.get("remaining_ratio", -1.0)), 1.0), "newly armed FUSE must expose the full wick length")
	_support.advance_frames(fixture, 21)
	var fuse_mid: Dictionary = fixture["runtime"].wall_leap_state.get_fuse_visual_snapshot()
	_expect(absf(float(fuse_mid.get("remaining_ratio", 0.0)) - 0.5) <= 0.03, "half of the 0.7-second fuse must leave half of the authored wick")
	_expect(absf(float(fuse_mid.get("remaining_length", 0.0)) - float(fuse_mid.get("authored_length", 0.0)) * 0.5) <= 2.0, "wick geometry must encode remaining fuse time as remaining length")
	_support.advance_frames(fixture, 22)
	return fixture


func _make_mid_fuse_fixture() -> Dictionary:
	var fixture: Dictionary = _support.make_fixture()
	_support.enter(fixture)
	_support.advance_to_infiltrating(fixture)
	_support.advance_frames(fixture, 16)
	_support.route_once(fixture, {"secondary_action_pressed": true, "secondary_action_just_pressed": true})
	_support.advance_frames(fixture, 21)
	return fixture


func _make_late_blast_fixture() -> Dictionary:
	var fixture := _make_committed_blast_fixture(50.0)
	_support.advance_frames(fixture, 29)
	return fixture


func _verify_fuse_render(fixture: Dictionary) -> void:
	var wall_state: Object = fixture["runtime"].wall_leap_state
	var fuse_projection: Dictionary = wall_state.get_fuse_visual_snapshot()
	_expect(absf(float(fuse_projection.get("remaining_ratio", 0.0)) - 0.5) <= 0.03, "windowed fuse fixture must capture the half-burn state")
	var ember_position: Vector2 = fuse_projection.get("ember_position", Vector2.ZERO)
	var wick_leading_position: Vector2 = fuse_projection.get("wick_leading_position", Vector2.INF)
	_expect(ember_position.is_equal_approx(wick_leading_position), "moving ember must track the burning wick front exactly")
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := BlastCanvas.new()
	canvas.wall_leap_state = wall_state
	viewport.add_child(canvas)
	wall_state.prewarm_runtime_nodes(canvas)
	canvas.queue_redraw()
	for _index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "burning-wick FUSE must render through a real CanvasItem")
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FUSE_CAPTURE_PATH.get_base_dir()))
		_expect(image.save_png(ProjectSettings.globalize_path(FUSE_CAPTURE_PATH)) == OK, "windowed burning-wick capture must save for visual review")
		var ember_center: Vector2 = fuse_projection.get("ember_position", Vector2.ZERO) + DRAW_OFFSET
		var powder_center: Vector2 = fuse_projection.get("powder_charge_position", Vector2.ZERO) + DRAW_OFFSET
		var ember_pixels := _count_hot_ember_pixels(image, ember_center, 38.0)
		var powder_pixels := _count_powder_charge_pixels(image, powder_center, 58.0)
		var cord_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				if color.r > 0.34 and color.g > 0.095 and color.r > color.g * 1.45 and color.b < 0.13:
					cord_pixels += 1
		print("wall_leap_rev10_fuse_pixels: ember=%d cord=%d powder=%d" % [ember_pixels, cord_pixels, powder_pixels])
		_expect(ember_pixels >= 220, "burning wick must expose a gameplay-readable white-hot/orange ember footprint")
		_expect(cord_pixels >= 350, "half-burn FUSE must retain a thick luminous physical cord")
		_expect(powder_pixels >= 1000, "FUSE must render the solid ink-blue/orange powder charge instead of a hollow placeholder")
	var host_status: Dictionary = wall_state.get_blast_vfx_host_status()
	_expect(int(host_status.get("layer_count", 0)) == 4, "FUSE host must own the fourth powder-charge texture layer")
	_expect(bool(host_status.get("powder_charge_visible", false)), "FUSE host must visibly present the powder charge")
	_expect(int(host_status.get("powder_charge_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX, "rendered powder charge must retain MIX blending")
	_expect(not bool(host_status.get("smoke_visible", true)) and not bool(host_status.get("blade_shards_visible", true)) and not bool(host_status.get("shock_ring_visible", true)), "FUSE must not wake the accepted explosion body before commit")
	viewport.queue_free()
	await process_frame
	fixture["runtime"].reset()
	_expect(not bool(wall_state.get_blast_vfx_host_status().get("powder_charge_visible", false)), "round/reset cleanup must hide the detached powder-charge host")


func _verify_rendered_layers(wall_state: Object) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := BlastCanvas.new()
	canvas.wall_leap_state = wall_state
	viewport.add_child(canvas)
	wall_state.prewarm_runtime_nodes(canvas)
	canvas.queue_redraw()
	for _index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "blast VFX seal must render through a real CanvasItem")
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WINDOWED_CAPTURE_PATH.get_base_dir()))
		_expect(image.save_png(ProjectSettings.globalize_path(WINDOWED_CAPTURE_PATH)) == OK, "windowed Serin blast capture must save for visual review")
		var warm_pixels := 0
		var ink_pixels := 0
		var changed_pixels := 0
		var outside_playfield_pixels := 0
		var background := BACKGROUND_COLOR
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				var delta := absf(color.r - background.r) + absf(color.g - background.g) + absf(color.b - background.b)
				if delta > 0.10:
					changed_pixels += 1
					if y < int(DRAW_OFFSET.y):
						outside_playfield_pixels += 1
				if color.r > 0.48 and color.g > 0.16 and color.r > color.b * 1.25:
					warm_pixels += 1
				if color.b > color.r * 1.10 and color.b > 0.075 and color.r < 0.34:
					ink_pixels += 1
		_expect(changed_pixels > 6000, "three-piece Serin blast must cover a substantial textured footprint")
		_expect(warm_pixels > 850, "blast must retain a readable white-gold and orange overpressure core")
		_expect(ink_pixels > 280, "MIX smoke must preserve a visible ink-blue outer mass on the dark field")
		_expect(outside_playfield_pixels == 0, "detached MIX/ADD blast layers must not leak above the playfield clip")
	var host_status: Dictionary = wall_state.get_blast_vfx_host_status()
	_expect(int(host_status.get("layer_count", 0)) == 4, "rendered Wall-Leap host must own all four authored texture layers")
	_expect(int(host_status.get("blast_layer_count", 0)) == 3, "accepted explosion body must remain exactly three texture layers")
	_expect(bool(host_status.get("playfield_clip_active", false)), "rendered blast host must keep all three layers under the playfield clip")
	_expect(int(host_status.get("smoke_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_MIX, "rendered smoke node must use MIX instead of ADD")
	_expect(int(host_status.get("blade_shards_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "rendered shard node must use ADD")
	_expect(int(host_status.get("shock_ring_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "rendered shock ring node must use ADD")
	_expect(not bool(host_status.get("powder_charge_visible", true)), "committed blast must hide the FUSE-only powder charge")
	viewport.queue_free()
	await process_frame


func _verify_late_shards_render(fixture: Dictionary) -> void:
	var wall_state: Object = fixture["runtime"].wall_leap_state
	var snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(bool(snapshot.get("wall_leap_raid_blast_vfx_active", false)), "late-shards fixture must remain alive after the accepted 0.46-second blast body")
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := BlastCanvas.new()
	canvas.wall_leap_state = wall_state
	viewport.add_child(canvas)
	wall_state.prewarm_runtime_nodes(canvas)
	canvas.queue_redraw()
	for _index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "late violet ember seal must render through a real CanvasItem")
	if image != null and not image.is_empty():
		_expect(image.save_png(ProjectSettings.globalize_path(LATE_SHARDS_CAPTURE_PATH)) == OK, "late violet ember capture must save for visual review")
		var blast_center: Vector2 = snapshot.get("wall_leap_raid_blast_vfx_origin", Vector2.ZERO) + DRAW_OFFSET
		var violet_pixels := _count_late_violet_pixels(image, blast_center, 175.0)
		print("wall_leap_rev10_late_violet_pixels: %d" % violet_pixels)
		_expect(violet_pixels >= 240, "blade-shard layer must leave a strict violet ember footprint after the orange blast body expires")
	var host_status: Dictionary = wall_state.get_blast_vfx_host_status()
	_expect(not bool(host_status.get("smoke_visible", true)), "accepted smoke body must be gone in the late violet-tail frame")
	_expect(not bool(host_status.get("shock_ring_visible", true)), "accepted shock ring must be gone in the late violet-tail frame")
	_expect(bool(host_status.get("blade_shards_visible", false)), "blade shards must remain visible after smoke and ring expire")
	viewport.queue_free()
	await process_frame


func _count_hot_ember_pixels(image: Image, center: Vector2, radius: float) -> int:
	var count := 0
	var min_x := maxi(0, int(floor(center.x - radius)))
	var max_x := mini(image.get_width(), int(ceil(center.x + radius)))
	var min_y := maxi(0, int(floor(center.y - radius)))
	var max_y := mini(image.get_height(), int(ceil(center.y + radius)))
	var radius_squared := radius * radius
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			if Vector2(float(x), float(y)).distance_squared_to(center) > radius_squared:
				continue
			var color := image.get_pixel(x, y)
			var white_hot := color.r > 0.74 and color.g > 0.58 and color.b > 0.36
			var orange_hot := color.r > 0.68 and color.g > 0.22 and color.b < 0.38 and color.r > color.g * 1.25
			if white_hot or orange_hot:
				count += 1
	return count


func _count_powder_charge_pixels(image: Image, center: Vector2, radius: float) -> int:
	var count := 0
	var min_x := maxi(0, int(floor(center.x - radius)))
	var max_x := mini(image.get_width(), int(ceil(center.x + radius)))
	var min_y := maxi(0, int(floor(center.y - radius)))
	var max_y := mini(image.get_height(), int(ceil(center.y + radius)))
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var color := image.get_pixel(x, y)
			var delta := absf(color.r - BACKGROUND_COLOR.r) + absf(color.g - BACKGROUND_COLOR.g) + absf(color.b - BACKGROUND_COLOR.b)
			var ink_body := delta > 0.085 and color.b > 0.072 and color.r < 0.42
			var orange_seal := color.r > 0.34 and color.g > 0.11 and color.r > color.b * 1.28
			if ink_body or orange_seal:
				count += 1
	return count


func _count_late_violet_pixels(image: Image, center: Vector2, radius: float) -> int:
	var count := 0
	var min_x := maxi(0, int(floor(center.x - radius)))
	var max_x := mini(image.get_width(), int(ceil(center.x + radius)))
	var min_y := maxi(0, int(floor(center.y - radius)))
	var max_y := mini(image.get_height(), int(ceil(center.y + radius)))
	var radius_squared := radius * radius
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			if Vector2(float(x), float(y)).distance_squared_to(center) > radius_squared:
				continue
			var color := image.get_pixel(x, y)
			if color.b > 0.15 and color.r > 0.10 and color.b > color.g * 1.12 and color.r > color.g * 1.02:
				count += 1
	return count


func _verify_source_contract() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_wall_leap_runtime.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/characters/viper_wall_leap_blast_fx_host.gd")
	var facade_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_runtime.gd")
	var draw_router_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_draw_runtime.gd")
	_expect(runtime_source.contains("ViperWallLeapBlastFxHost"), "Wall-Leap runtime must delegate the blast to the dedicated Serin host")
	_expect(facade_source.contains("wall_leap_state.prewarm_runtime_nodes(owner)"), "Viper facade prewarm must build the Wall-Leap host before the first visible blast")
	_expect(draw_router_source.contains("wall_leap_state.draw_effects(canvas, shake_offset, node_fx_layout)"), "production Viper draw router must pass screen layout into the Wall-Leap host")
	_expect(runtime_source.contains("_build_remaining_wick"), "FUSE must use the shrinking burning-wick projection")
	_expect(not runtime_source.contains("BLAST_RAY_COUNT"), "rev7 evenly spaced procedural rays must stay removed")
	_expect(not runtime_source.contains("_draw_blast_ring"), "rev7 cyan-violet double shockwave helper must stay removed")
	_expect(not runtime_source.contains("ImpactShockwaveTextureCache"), "Wall-Leap must not fall back to the generic sci-fi ring cache")
	_expect(host_source.contains(SMOKE_PATH) and host_source.contains(SHARDS_PATH) and host_source.contains(RING_PATH), "dedicated host must keep all three accepted rev9 blast texture paths")
	_expect(host_source.contains(POWDER_CHARGE_PATH), "dedicated host must own the rev10 powder-charge texture path")
	_expect(host_source.contains("BLEND_MODE_MIX") and host_source.contains("BLEND_MODE_ADD"), "dedicated host source must preserve the MIX/ADD material split")
	_expect(not runtime_source.contains("draw_colored_polygon(powder_bundle"), "FUSE must not regress to the hollow procedural powder placeholder")
	_expect(runtime_source.contains("FUSE_EMBER_VISUAL_SCALE") and runtime_source.contains("BLAST_SHARDS_TAIL_SECONDS"), "FUSE readability and late-shards lifetime must remain explicit runtime contracts")


func _verify_texture_alpha_contract(path: String, expected_size: Vector2i) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s must decode as a PNG" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s must keep its authored target resolution" % path)
	_expect(image.detect_alpha(), "%s must contain real alpha rather than a baked checkerboard/background" % path)
	var width := image.get_width()
	var height := image.get_height()
	var horizontal_margins_clear := true
	for x in range(width):
		if image.get_pixel(x, 0).a > 0.001 or image.get_pixel(x, height - 1).a > 0.001:
			horizontal_margins_clear = false
			break
	var vertical_margins_clear := true
	for y in range(height):
		if image.get_pixel(0, y).a > 0.001 or image.get_pixel(width - 1, y).a > 0.001:
			vertical_margins_clear = false
			break
	_expect(horizontal_margins_clear, "%s must keep transparent top/bottom margins" % path)
	_expect(vertical_margins_clear, "%s must keep transparent left/right margins" % path)


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
