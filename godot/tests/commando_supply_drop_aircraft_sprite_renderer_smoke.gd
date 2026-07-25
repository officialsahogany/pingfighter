extends SceneTree

const AircraftSpriteRenderer := preload("res://scripts/characters/commando_supply_drop_aircraft_sprite_renderer.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")

var failure_count: int = 0


func _init() -> void:
	_expect(AircraftSpriteRenderer.get_tilt_frame(-1.0) == 0, "tilt animation should clamp negative elapsed time")
	_expect(AircraftSpriteRenderer.get_tilt_frame(0.90) == 15, "tilt animation should resolve the final 4x4 frame")
	_expect(AircraftSpriteRenderer.get_tilt_frame(0.96) == 0, "tilt animation should loop after sixteen frames")
	var crash_interval := CommandoSupplyDropState.AIRCRAFT_CRASH_FRAME_INTERVAL
	_expect(AircraftSpriteRenderer.get_crash_frame(-1.0, crash_interval) == 0, "crash animation should clamp negative elapsed time")
	_expect(AircraftSpriteRenderer.get_crash_frame(99.0, crash_interval) == 15, "crash animation should hold its final frame")

	_expect(
		AircraftSpriteRenderer.get_tilt_sheet_path("right_to_left").ends_with("_left.png"),
		"right-to-left flight should use the native left-facing sheet"
	)
	_expect(
		AircraftSpriteRenderer.get_crash_sheet_path("left_to_right").ends_with("_right.png"),
		"left-to-right crash should use the mirrored right-facing sheet"
	)

	var image := Image.create(400, 400, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var source := Rect2(100.0, 200.0, 100.0, 100.0)
	var quad := AircraftSpriteRenderer.build_rotated_quad(
		texture,
		source,
		Vector2(50.0, 60.0),
		Vector2(40.0, 20.0),
		0.0
	)
	var uvs: PackedVector2Array = quad.get("uvs", PackedVector2Array())
	var points: PackedVector2Array = quad.get("points", PackedVector2Array())
	_expect(points.size() == 4 and uvs.size() == 4, "rotated aircraft quad should expose four matching corners")
	if uvs.size() == 4:
		_expect(uvs[0].is_equal_approx(Vector2(0.25, 0.50)), "quad TL UV should normalize the atlas source position")
		_expect(uvs[2].is_equal_approx(Vector2(0.50, 0.75)), "quad BR UV should normalize the atlas source end")
		for uv in uvs:
			_expect(uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0, "aircraft draw_polygon UVs must stay normalized")

	AircraftSpriteRenderer.prewarm_assets()
	var status := AircraftSpriteRenderer.build_status(
		"left_to_right",
		0.0,
		0.0,
		crash_interval,
		CommandoSupplyDropState.AIRCRAFT_SPEED_PIXELS_PER_SECOND,
		12.0
	)
	_expect(bool(status.get("active_loaded", false)), "active aircraft sheet should prewarm")
	_expect(bool(status.get("crash_active_loaded", false)), "crash aircraft sheet should prewarm")
	_expect(int(status.get("frame_count", 0)) == 16, "status should preserve the active sheet contract")
	_expect(int(status.get("crash_frame_count", 0)) == 16, "status should preserve the crash sheet contract")

	if failure_count > 0:
		quit(1)
		return
	print("commando_supply_drop_aircraft_sprite_renderer_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
