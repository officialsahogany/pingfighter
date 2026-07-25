extends RefCounted

# Pure geometry/envelope owner for the title-screen gate-opening transition.
# The scene owns CanvasItem drawing, audio, tweens, and navigation.

const BEAM_TOP_RATIO := 0.35
const OPENED_BEAM_WIDTH_RATIO := 0.72
const IDLE_LIGHT_SCALE := 0.825
const START_LIGHT_BOOST_SCALE := 1.12
const EDGE_FEATHER_SOURCE_PX := 36.0
const EDGE_FEATHER_MIN_PX := 24.0
const EDGE_FEATHER_MAX_PX := 48.0
const LIGHT_PEAK_Y_RATIO := 0.60
const LIGHT_TOP_WEIGHT := 0.28
const LIGHT_BOTTOM_WEIGHT := 0.55


static func build_frame(raw_progress: float, view_size: Vector2) -> Dictionary:
	var progress := clampf(raw_progress, 0.0, 1.0)
	var safe_size := Vector2(maxf(view_size.x, 1.0), maxf(view_size.y, 1.0))
	var center_x := safe_size.x * 0.5
	var windup := _smoothstep01(progress / 0.28)
	var opening := _smoothstep01((progress - 0.14) / 0.66)
	var finish := _smoothstep01((progress - 0.78) / 0.22)
	var seam_width := maxf(6.0 * safe_size.x / 1920.0, 2.0)
	var opened_width := safe_size.x * OPENED_BEAM_WIDTH_RATIO
	var beam_width := lerpf(seam_width, opened_width, pow(opening, 1.22))
	var beam_top := safe_size.y * BEAM_TOP_RATIO
	var light_peak_y := safe_size.y * LIGHT_PEAK_Y_RATIO
	var beam_rect := Rect2(
		Vector2(center_x - beam_width * 0.5, beam_top),
		Vector2(beam_width, safe_size.y - beam_top)
	)
	var door_shadow_alpha := lerpf(0.12, 0.68, _smoothstep01((progress - 0.06) / 0.70))
	var start_light_scale := lerpf(IDLE_LIGHT_SCALE, START_LIGHT_BOOST_SCALE, windup)
	var edge_feather_px := clampf(
		EDGE_FEATHER_SOURCE_PX * safe_size.y / 1080.0,
		EDGE_FEATHER_MIN_PX,
		EDGE_FEATHER_MAX_PX
	)
	var left_panel := Rect2(Vector2.ZERO, Vector2(maxf(beam_rect.position.x, 0.0), safe_size.y))
	var right_x := minf(beam_rect.end.x, safe_size.x)
	var right_panel := Rect2(Vector2(right_x, 0.0), Vector2(maxf(safe_size.x - right_x, 0.0), safe_size.y))
	return {
		"progress": progress,
		"windup": windup,
		"opening": opening,
		"finish": finish,
		"beam_rect": beam_rect,
		"left_panel_rect": left_panel,
		"right_panel_rect": right_panel,
		"door_shadow_alpha": door_shadow_alpha,
		"start_light_scale": start_light_scale,
		"edge_feather_px": edge_feather_px,
		"light_peak_y": light_peak_y,
		"light_top_weight": LIGHT_TOP_WEIGHT,
		"light_bottom_weight": LIGHT_BOTTOM_WEIGHT,
		"beam_alpha": lerpf(0.12, 0.62, maxf(windup * 0.68, opening)),
		"core_alpha": lerpf(0.28, 0.84, maxf(windup, opening)),
		"whitewash_alpha": finish * 0.88,
	}


static func _smoothstep01(value: float) -> float:
	var amount := clampf(value, 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)
