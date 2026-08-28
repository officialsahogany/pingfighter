extends SceneTree

# Seal: Hwangyeok top-mini scoreboard A/B/C runtime integration.
#
# Covers the five contracts that can silently look GREEN in source-only review:
# texture-readiness re-apply, narrow-band geometry clamp, exact atlas mapping,
# fixed white core, and boss-danger visual channel separation.

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ScoreboardRenderer := preload("res://scripts/hud/scoreboard_renderer.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const ScoreboardTopMiniDigitAtlasRenderer := preload("res://scripts/hud/scoreboard_top_mini_digit_atlas_renderer.gd")
const ScoreboardTopMiniNormalRenderer := preload("res://scripts/hud/scoreboard_top_mini_normal_renderer.gd")
const ScoreboardTopMiniRenderer := preload("res://scripts/hud/scoreboard_top_mini_renderer.gd")
const ScoreboardTopMiniRetainedHost := preload("res://scripts/hud/scoreboard_top_mini_retained_host.gd")

var _failures: Array[String] = []


class CaptureNormalRenderer:
	extends RefCounted

	var draw_calls: int = 0
	var last_rect: Rect2 = Rect2()

	func draw(
		_canvas: Node2D,
		rect: Rect2,
		_scale_factor: float,
		_sparkle_progress: float,
		_sparkle_intensity: float,
		_player_score: int,
		_boss_score: int,
		_quality_scale: float = 1.0,
		_stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_rect = rect


class CaptureAtlasTexture:
	extends Texture2D

	var region_calls: Array[Dictionary] = []

	func _get_width() -> int:
		return 1280

	func _get_height() -> int:
		return 256

	func _has_alpha() -> bool:
		return true

	func _draw_rect_region(
		_to_canvas_item: RID,
		rect: Rect2,
		source_rect: Rect2,
		modulate: Color,
		transpose: bool,
		clip_uv: bool
	) -> void:
		region_calls.append({
			"rect": rect,
			"source_rect": source_rect,
			"modulate": modulate,
			"transpose": transpose,
			"clip_uv": clip_uv,
		})


class CorePaletteProbe:
	extends Node2D

	var atlas: Object = null
	var texture: Texture2D = null
	var body_color := Color.WHITE
	var glow_color := Color.WHITE
	var drew := false

	func _draw() -> void:
		drew = atlas != null and atlas.draw_number(
			self,
			texture,
			Rect2(18.0, 6.0, 60.0, 33.0),
			0,
			body_color,
			glow_color,
			1.0,
			0.91,
			1.0
		)


class CapturePolishChromeRenderer:
	extends RefCounted

	var sparkle_values: Array[float] = []
	var knot_values: Array[float] = []

	func draw_background(
		_canvas: Node2D,
		_rect: Rect2,
		_scale_factor: float,
		sparkle_intensity: float,
		_quality_scale: float = 1.0,
		_stakes: Dictionary = {},
		_textures: Dictionary = {},
		_status_color: Color = Color.WHITE,
		knot_boost: float = 0.5,
		_status_boost: float = 0.0
	) -> bool:
		sparkle_values.append(sparkle_intensity)
		knot_values.append(knot_boost)
		return true


class CapturePolishAtlasRenderer:
	extends RefCounted

	var panel_rects: Array[Rect2] = []

	func draw_number(
		_canvas: CanvasItem,
		_texture: Texture2D,
		panel_rect: Rect2,
		_value: int,
		_body_color: Color,
		_glow_color: Color,
		_glow_intensity: float,
		_core_alpha: float,
		_quality_scale: float = 1.0,
		_center_offset: Vector2 = Vector2.ZERO
	) -> bool:
		panel_rects.append(panel_rect)
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_texture_ready_state_key_and_retained_reapply()
	_verify_box_geometry_uses_aspect_and_narrow_band_clamp()
	_verify_hand_painted_brush_digit_asset()
	_verify_atlas_mapping_and_two_digit_width()
	_verify_final_polish_layout_and_digit_only_score_pulse()
	await _verify_core_stays_fixed_white_for_every_status_palette()
	_verify_boss_danger_has_a_distinct_visual_channel()

	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("scoreboard_top_mini_hwangyeok_restyle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_texture_ready_state_key_and_retained_reapply() -> void:
	ProjectResourceLoader.clear_caches()
	var top_renderer := ScoreboardTopMiniRenderer.new()
	_expect(
		not top_renderer.are_hwangyeok_textures_ready(),
		"texture_ready should be false when the cache has none of A/B/C"
	)
	var texture_paths: Array[String] = [
		BattleCoreTexturePaths.SCOREBOARD_TOP_MINI_HWANGYEOK_FRAME_TEXTURE_PATH,
		BattleCoreTexturePaths.SCOREBOARD_TOP_MINI_HWANGYEOK_GLOW_TEXTURE_PATH,
		BattleCoreTexturePaths.SCOREBOARD_TOP_MINI_HWANGYEOK_DIGITS_TEXTURE_PATH,
	]
	var placeholders: Array[Texture2D] = []
	for path in texture_paths:
		_expect(FileAccess.file_exists(path), "scoreboard asset must exist: %s" % path)
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(64.0, 64.0)
		placeholders.append(placeholder)
		ProjectResourceLoader.store_texture(path, placeholder)
	_expect(
		top_renderer.are_hwangyeok_textures_ready(),
		"texture_ready should become true only after all three cached peeks succeed"
	)

	var scoreboard_renderer := ScoreboardRenderer.new()
	var unready_key: Array = scoreboard_renderer._build_top_mini_state_key(
		Vector2(260.0, 40.0),
		Vector2(760.0, 750.0),
		760.0,
		3,
		1,
		false,
		1.0,
		{},
		0.0,
		false
	)
	var ready_key: Array = scoreboard_renderer._build_top_mini_state_key(
		Vector2(260.0, 40.0),
		Vector2(760.0, 750.0),
		760.0,
		3,
		1,
		false,
		1.0,
		{},
		0.0,
		true
	)
	_expect(unready_key != ready_key, "texture_ready false/true must produce different retained state keys")

	var host := ScoreboardTopMiniRetainedHost.new()
	root.add_child(host)
	host.update_state(null, [], unready_key, false)
	var requests_before_ready: int = host.redraw_request_count
	host.update_state(null, [], ready_key, false)
	_expect(
		host.redraw_request_count == requests_before_ready + 1,
		"texture readiness transition must request exactly one retained redraw"
	)
	host.update_state(null, [], ready_key, false)
	_expect(
		host.redraw_request_count == requests_before_ready + 1,
		"settled texture readiness must not keep requesting redraws"
	)
	root.remove_child(host)
	host.free()
	placeholders.clear()
	ProjectResourceLoader.clear_caches()


func _verify_box_geometry_uses_aspect_and_narrow_band_clamp() -> void:
	var renderer := ScoreboardTopMiniRenderer.new()
	var capture := CaptureNormalRenderer.new()
	renderer.normal_renderer = capture
	var canvas := Node2D.new()
	renderer.draw(
		canvas,
		Vector2(260.0, 21.0),
		Vector2(760.0, 750.0),
		760.0,
		3,
		1,
		false,
		0.0,
		0.35,
		0.0,
		1.0,
		{}
	)
	_expect(capture.draw_calls == 1, "narrow-band fixture must reach the production box calculation")
	var narrow_rect: Rect2 = capture.last_rect
	_expect(
		absf(narrow_rect.size.x / narrow_rect.size.y - ScoreboardTopMiniRenderer.BOARD_ASPECT) <= 0.01,
		"top-mini box aspect must stay 3.585 within tolerance"
	)
	_expect(narrow_rect.size.y < 30.0, "21px band fixture must actually exercise the height clamp")
	_expect(
		narrow_rect.end.y <= 21.0 + 0.001,
		"clamped top-mini rect must stay inside the top letterbox band"
	)
	canvas.free()


func _verify_hand_painted_brush_digit_asset() -> void:
	var path := BattleCoreTexturePaths.SCOREBOARD_TOP_MINI_HWANGYEOK_DIGITS_TEXTURE_PATH
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(not image.is_empty(), "hand-painted brush digit atlas must load from the production path")
	if image.is_empty():
		return
	_expect(image.get_size() == Vector2i(1280, 256), "brush digit atlas must remain 10x2 128px cells")
	var expected_widths := [76, 52, 84, 76, 82, 82, 76, 78, 70, 72]
	var hole_probes := {
		0: [Vector2i(64, 64)],
		6: [Vector2i(64, 76)],
		8: [Vector2i(64, 48), Vector2i(64, 78)],
		9: [Vector2i(64, 48)],
	}
	for digit in range(10):
		var min_x := 128
		var min_y := 128
		var max_x := -1
		var max_y := -1
		var visible_pixels := 0
		var partial_alpha_pixels := 0
		var core_pixels := 0
		for y in range(128):
			for x in range(128):
				var body := image.get_pixel(digit * 128 + x, y)
				var core := image.get_pixel(digit * 128 + x, 128 + y)
				if body.a >= 32.0 / 255.0:
					visible_pixels += 1
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
					_expect(
						body.r >= 0.96 and body.g >= 0.96 and body.b >= 0.96,
						"digit %d body RGB must stay near-white so runtime modulate owns its ink color" % digit
					)
				if body.a >= 12.0 / 255.0 and body.a <= 243.0 / 255.0:
					partial_alpha_pixels += 1
				if core.a >= 32.0 / 255.0:
					core_pixels += 1
				_expect(
					core.a <= body.a + 0.001,
					"digit %d core mask must be derived wholly inside the body alpha" % digit
				)
		var measured_width := max_x - min_x + 1
		var measured_height := max_y - min_y + 1
		_expect(measured_width == int(expected_widths[digit]), "digit %d optical width must match its measured renderer metric" % digit)
		_expect(measured_height == 96 and min_y == 16 and max_y == 111, "digit %d must retain the common 96px cap box" % digit)
		_expect(visible_pixels >= 1800, "digit %d must retain enough brush mass after downscale" % digit)
		_expect(core_pixels >= 650, "digit %d must retain a readable fixed-white core after erosion" % digit)
		_expect(
			float(partial_alpha_pixels) / maxf(float(visible_pixels), 1.0) >= 0.15,
			"digit %d must retain split-bristle and dry-brush partial alpha instead of becoming a font silhouette" % digit
		)
		for probe_value in hole_probes.get(digit, []):
			var probe: Vector2i = probe_value
			_expect(
				image.get_pixel(digit * 128 + probe.x, probe.y).a <= 0.02,
				"digit %d internal counter must stay open at %s" % [digit, str(probe)]
			)
		for edge_index in range(128):
			_expect(
				image.get_pixel(digit * 128, edge_index).a <= 0.001
				and image.get_pixel(digit * 128 + 127, edge_index).a <= 0.001
				and image.get_pixel(digit * 128 + edge_index, 0).a <= 0.001
				and image.get_pixel(digit * 128 + edge_index, 127).a <= 0.001,
				"digit %d must keep a clean transparent border inside its atlas cell" % digit
			)


func _verify_atlas_mapping_and_two_digit_width() -> void:
	var atlas := ScoreboardTopMiniDigitAtlasRenderer.new()
	var panel_rect := Rect2(0.0, 0.0, 60.0, 33.0)
	for score in range(11):
		var layout: Dictionary = atlas.build_number_layout(panel_rect, score)
		var text := str(score)
		var body_sources: Array = layout.get("body_source_rects", [])
		var core_sources: Array = layout.get("core_source_rects", [])
		var body_rects: Array = layout.get("body_draw_rects", [])
		var core_rects: Array = layout.get("core_draw_rects", [])
		_expect(body_sources.size() == text.length(), "body source count must match score %d digits" % score)
		_expect(core_sources.size() == text.length(), "core source count must match score %d digits" % score)
		for digit_index in range(text.length()):
			var digit: int = int(text.substr(digit_index, 1))
			var expected_body := Rect2(float(digit) * 128.0, 0.0, 128.0, 128.0)
			var expected_core := Rect2(float(digit) * 128.0, 128.0, 128.0, 128.0)
			_expect(body_sources[digit_index] == expected_body, "score %d body source rect must map exact atlas cell" % score)
			_expect(core_sources[digit_index] == expected_core, "score %d core source rect must map exact atlas cell" % score)
			_expect(body_rects[digit_index] == core_rects[digit_index], "score %d core/body destination rects must be identical" % score)
		_expect(
			float(layout.get("total_width", INF)) <= panel_rect.size.x * 0.92 + 0.001,
			"score %d must stay within 92 percent of the panel width" % score
		)

	var ten_layout: Dictionary = atlas.build_number_layout(panel_rect, 10)
	_expect(
		is_equal_approx(float(ten_layout.get("cap_height", 0.0)), panel_rect.size.y * 0.92),
		"score 10 should retain the hand-painted atlas' 0.92 cap ratio when it fits"
	)
	var narrow_layout: Dictionary = atlas.build_number_layout(Rect2(0.0, 0.0, 35.0, 33.0), 10)
	_expect(
		float(narrow_layout.get("total_width", INF)) <= 35.0 * 0.92 + 0.001,
		"two-digit overflow guard must reduce cap height until score 10 fits"
	)


func _verify_final_polish_layout_and_digit_only_score_pulse() -> void:
	_expect(
		is_equal_approx(ScoreboardState.TOP_MINI_SCORE_SPARKLE_DURATION, 0.16),
		"score-change pulse must stay inside the approved 0.1-0.2 second window"
	)
	var renderer := ScoreboardTopMiniNormalRenderer.new()
	var chrome := CapturePolishChromeRenderer.new()
	var atlas := CapturePolishAtlasRenderer.new()
	renderer.chrome_renderer = chrome
	renderer.atlas_renderer = atlas
	var canvas := Node2D.new()
	var frame := PlaceholderTexture2D.new()
	var glow := PlaceholderTexture2D.new()
	var digits := PlaceholderTexture2D.new()
	frame.size = Vector2(64.0, 64.0)
	glow.size = Vector2(64.0, 64.0)
	digits.size = Vector2(64.0, 64.0)
	var board_rect := Rect2(20.0, 6.0, 212.0, 59.0)
	var base_layout: Dictionary = renderer._get_score_layout(board_rect)
	var player_base: Rect2 = base_layout.get("player_rect", Rect2())
	var boss_base: Rect2 = base_layout.get("boss_rect", Rect2())
	_expect(
		is_equal_approx(player_base.end.x, board_rect.position.x + board_rect.size.x * 0.442)
		and is_equal_approx(boss_base.position.x, board_rect.position.x + board_rect.size.x * 0.558),
		"final polish must narrow the central column to 0.442-0.558"
	)
	renderer.draw(
		canvas,
		board_rect,
		1.0,
		0.5,
		1.0,
		10,
		9,
		1.0,
		{},
		{"frame": frame, "glow": glow, "digits": digits}
	)
	_expect(
		chrome.sparkle_values == [0.0] and chrome.knot_values == [0.0],
		"score changes must not pulse the frame, dancheong, or central knot"
	)
	_expect(atlas.panel_rects.size() == 2, "score pulse fixture must traverse both digit draws")
	if atlas.panel_rects.size() == 2:
		_expect(
			atlas.panel_rects[0].get_center().is_equal_approx(player_base.get_center())
			and atlas.panel_rects[1].get_center().is_equal_approx(boss_base.get_center()),
			"digit pulse must preserve both score centers"
		)
		_expect(
			atlas.panel_rects[0].size.is_equal_approx(player_base.size * 1.018)
			and atlas.panel_rects[1].size.is_equal_approx(boss_base.size * 1.018),
			"peak score pulse must be a subtle 1.8 percent scale-up"
		)
	canvas.free()


func _verify_core_stays_fixed_white_for_every_status_palette() -> void:
	var atlas := ScoreboardTopMiniDigitAtlasRenderer.new()
	var texture := CaptureAtlasTexture.new()
	var probe := CorePaletteProbe.new()
	probe.atlas = atlas
	probe.texture = texture
	root.add_child(probe)
	var palettes := [
		{"name": "normal", "body": Color(208.0 / 255.0, 240.0 / 255.0, 240.0 / 255.0), "glow": Color(75.0 / 255.0, 131.0 / 255.0, 209.0 / 255.0)},
		{"name": "opportunity", "body": Color(1.0, 222.0 / 255.0, 86.0 / 255.0), "glow": Color(1.0, 194.0 / 255.0, 40.0 / 255.0)},
		{"name": "danger", "body": Color(240.0 / 255.0, 208.0 / 255.0, 208.0 / 255.0), "glow": Color(237.0 / 255.0, 76.0 / 255.0, 76.0 / 255.0)},
		{"name": "deuce", "body": Color(1.0, 176.0 / 255.0, 86.0 / 255.0), "glow": Color(1.0, 92.0 / 255.0, 18.0 / 255.0)},
	]
	for palette in palettes:
		var body_color: Color = palette["body"]
		texture.region_calls.clear()
		probe.body_color = body_color
		probe.glow_color = palette["glow"]
		probe.drew = false
		probe.queue_redraw()
		for _frame in range(3):
			await process_frame
			if probe.drew and not texture.region_calls.is_empty():
				break
		_expect(probe.drew, "%s palette must traverse draw_number inside a real draw callback" % palette["name"])
		var opaque_body_calls := 0
		var core_calls := 0
		for call in texture.region_calls:
			var source_rect: Rect2 = call["source_rect"]
			var modulate: Color = call["modulate"]
			if is_equal_approx(source_rect.position.y, 128.0):
				core_calls += 1
				_expect(
					is_equal_approx(modulate.r, 243.0 / 255.0)
					and is_equal_approx(modulate.g, 1.0)
					and is_equal_approx(modulate.b, 1.0)
					and is_equal_approx(modulate.a, 0.91),
					"%s core-row draw must use fixed #f3ffff at the production callsite" % palette["name"]
				)
			elif is_equal_approx(source_rect.position.y, 0.0) and modulate.is_equal_approx(body_color):
				opaque_body_calls += 1
		_expect(core_calls == 1, "%s palette must emit one captured core-row pass" % palette["name"])
		_expect(opaque_body_calls == 1, "%s palette must preserve its body color on the opaque body-row pass" % palette["name"])
	root.remove_child(probe)
	probe.free()


func _verify_boss_danger_has_a_distinct_visual_channel() -> void:
	var renderer := ScoreboardTopMiniNormalRenderer.new()
	var normal_stakes := {}
	var danger_stakes := {"boss_can_win": true}
	_expect(
		renderer._get_boss_score_color(normal_stakes) == renderer._get_boss_score_color(danger_stakes),
		"boss body color should intentionally stay on the approved bright fill in both states"
	)
	_expect(
		renderer._get_boss_glow_color(normal_stakes) != renderer._get_boss_glow_color(danger_stakes),
		"boss danger must change the saturated digit glow channel"
	)
	_expect(
		renderer._get_frame_status_color(normal_stakes) != renderer._get_frame_status_color(danger_stakes),
		"boss danger must change the whole-board B-mask status channel"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
