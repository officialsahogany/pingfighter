extends SceneTree

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const PingpongBallRenderer := preload("res://scripts/ball/pingpong_ball_renderer.gd")
const Stage2VariantBossRenderer := preload(
	"res://scripts/stages/stage2/stage2_variant_boss_renderer.gd"
)
const Stage3MenheraBossActorRenderer := preload(
	"res://scripts/stages/stage3/stage3_menhera_boss_actor_renderer.gd"
)
const Stage3VariantBossRenderer := preload(
	"res://scripts/stages/stage3/stage3_variant_boss_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const BOSS_POS := Vector2(330.0, 25.0)
const BALL_POS := Vector2(380.0, 390.0)
const BEFORE_SENTINEL_POS := Vector2(315.0, 575.0)
const AFTER_SENTINEL_POS := Vector2(425.0, 575.0)
const BEFORE_SENTINEL_COLOR := Color(0.05, 1.0, 0.10, 1.0)
const AFTER_SENTINEL_COLOR := Color(1.0, 0.05, 0.95, 1.0)
const EXPECTED_CAPTURE_LEG_COUNT := 4
const CAPTURE_SPECS := [
	{"id": "stage3_teddy_bear", "renderer": "stage3_variant", "variant": "teddy_bear"},
	{"id": "stage3_alice", "renderer": "stage3_variant", "variant": "alice"},
	{"id": "stage3_yeonmyo", "renderer": "stage3_yeonmyo", "variant": "yeonmyo"},
	{"id": "stage2_molewang", "renderer": "stage2_variant", "variant": "molewang"},
]

var _failed := false
var _force_legacy_reset := false
var _output_dir := "res://.tmp/playfield_transform_retention"
var _layout: Dictionary = {}
var _probe: PlayfieldTransformProbe = null


class PlayfieldTransformProbe:
	extends Node2D

	var layout: Dictionary = {}
	var spec: Dictionary = {}
	var inject_legacy_reset := false
	var stage2_variant_renderer: Object = null
	var stage3_yeonmyo_renderer: Object = null
	var stage3_variant_renderer: Object = null
	var ball_renderer: Object = null

	func _draw() -> void:
		var view_size := Vector2(VIEW_SIZE)
		var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
		var game_size: Vector2 = layout.get("game_size", PLAYFIELD_SIZE)
		var render_scale: float = float(layout.get("render_scale", 1.0))
		draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK, true)
		draw_rect(
			Rect2(game_offset, game_size),
			Color(0.025, 0.035, 0.055, 1.0),
			true
		)
		draw_set_transform(game_offset, 0.0, Vector2.ONE * render_scale)
		draw_circle(BEFORE_SENTINEL_POS, 7.0, BEFORE_SENTINEL_COLOR)
		# Counterproof-only recreation of the historical child reset. It runs
		# after the transformed pre-sentinel and before the boss/ball, matching
		# the visible failure signature without modifying production source.
		if inject_legacy_reset:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_boss()
		ball_renderer.draw(self, BALL_POS, null, Vector2(8.0, -5.0))
		draw_circle(AFTER_SENTINEL_POS, 7.0, AFTER_SENTINEL_COLOR)
		# This probe owns the top-level transform and restores it only after the
		# complete playfield pass; child renderers may never do this themselves.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_boss() -> void:
		var context := {
			"current_stage": 3,
			"stage_boss_variant": str(spec.get("variant", "")),
			"boss_pos": BOSS_POS,
			"boss_draw_pos": BOSS_POS,
			"boss_paddle_size": Vector2(100.0, 40.0),
			"boss_hitbox_height": 40.0,
			"ball_pos": BALL_POS,
			"player_pos": Vector2(302.5, 680.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"effect_lod_scale": 1.0,
			"molewang_hit_emerge_progress": 0.35,
		}
		match str(spec.get("renderer", "")):
			"stage3_variant":
				stage3_variant_renderer.draw(self, context, Vector2.ZERO)
			"stage3_yeonmyo":
				stage3_yeonmyo_renderer.draw(self, context, Vector2.ZERO)
			"stage2_variant":
				context["current_stage"] = 2
				stage2_variant_renderer.draw(self, context, Vector2.ZERO)


func _init() -> void:
	_parse_args()
	get_root().size = VIEW_SIZE
	RenderingServer.set_default_clear_color(Color.BLACK)
	_layout = BattleViewLayout.new().build_game_layout(
		Vector2(VIEW_SIZE), PLAYFIELD_SIZE.x, PLAYFIELD_SIZE.y
	)
	_probe = PlayfieldTransformProbe.new()
	_probe.layout = _layout
	_probe.stage2_variant_renderer = Stage2VariantBossRenderer.new()
	_probe.stage3_yeonmyo_renderer = Stage3MenheraBossActorRenderer.new()
	_probe.stage3_variant_renderer = Stage3VariantBossRenderer.new()
	_probe.ball_renderer = PingpongBallRenderer.new()
	get_root().add_child(_probe)
	call_deferred("_run")


func _run() -> void:
	_verify_contract_sources()
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print(
			"playfield_draw_transform_retention_pixel_smoke: "
			+ "pixel QA skipped under headless display server"
		)
		_finish()
		return

	# The sibling leg needs the real walk sheet, not all six victory/defeat/
	# attack sheets. Materialize the production walk frame source, then close
	# the QA-only prewarm latch so draw() exercises the real actor path without
	# turning this focused transform seal into a full asset-prewarm benchmark.
	if not _force_legacy_reset:
		_probe.stage3_yeonmyo_renderer.prewarm_assets_step()
		_probe.stage3_yeonmyo_renderer.set("_assets_prewarmed", true)
	var capture_count := 0
	var run_specs: Array = CAPTURE_SPECS
	if _force_legacy_reset:
		run_specs = [CAPTURE_SPECS[0]]
	for spec in run_specs:
		var image: Image = await _capture(spec, _force_legacy_reset)
		if image == null:
			continue
		capture_count += 1
		_verify_green_capture(image, spec)
		_save_capture(image, str(spec.get("id", "capture")))

	if not _force_legacy_reset:
		var counterproof: Image = await _capture(CAPTURE_SPECS[0], true)
		if counterproof != null:
			_verify_counterproof_signature(counterproof)
			_save_capture(counterproof, "counterproof_legacy_reset")
	else:
		print(
			"playfield_draw_transform_retention_pixel_smoke: "
			+ "forced legacy reset should make the GREEN assertions RED"
		)

	var expected_capture_count := EXPECTED_CAPTURE_LEG_COUNT
	if _force_legacy_reset:
		expected_capture_count = 1
	_expect(capture_count == expected_capture_count, "windowed QA capture count mismatch")
	print(
		"playfield_draw_transform_retention_pixel_smoke: captures=%d" % capture_count
	)
	_finish()


func _verify_contract_sources() -> void:
	_expect(
		CAPTURE_SPECS.size() == EXPECTED_CAPTURE_LEG_COUNT,
		"capture leg count must be updated with the capture manifest"
	)
	var required_ids := [
		"stage3_teddy_bear",
		"stage3_alice",
		"stage3_yeonmyo",
		"stage2_molewang",
	]
	var actual_ids: Array[String] = []
	for spec in CAPTURE_SPECS:
		actual_ids.append(str(spec.get("id", "")))
	for required_id in required_ids:
		_expect(required_id in actual_ids, "missing transform-retention leg: %s" % required_id)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage3/stage3_variant_boss_renderer.gd"
	)
	_expect(
		renderer_source.find("draw_set_" + "transform") < 0,
		"Stage 3 variant boss renderer must not mutate the playfield transform"
	)
	var wrapper_source := FileAccess.get_file_as_string(
		"res://tools/run_playfield_transform_retention_visual_qa.ps1"
	)
	_expect(
		wrapper_source.find("-AllowDuringPlay") >= 0,
		"windowed transform QA must use the standard live-process guard"
	)
	_expect(
		wrapper_source.find("--resolution", 0) >= 0
		and wrapper_source.find("2020x1246", 0) >= 0
		and wrapper_source.find("--rendering-driver", 0) >= 0
		and wrapper_source.find("vulkan", 0) >= 0,
		"windowed transform QA must pin the 2020x1246 Vulkan acceptance surface"
	)


func _capture(spec: Dictionary, inject_legacy_reset: bool) -> Image:
	_probe.spec = spec
	_probe.inject_legacy_reset = inject_legacy_reset
	_probe.queue_redraw()
	for _frame in range(4):
		await process_frame
	var texture := get_root().get_texture()
	if texture == null:
		_expect(false, "windowed QA must obtain the viewport texture")
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_expect(false, "windowed QA must obtain a non-empty viewport image")
		return null
	_expect(
		image.get_size() == VIEW_SIZE,
		"capture must use the exact 2020x1246 acceptance resolution"
	)
	return image


func _verify_green_capture(image: Image, spec: Dictionary) -> void:
	var game_offset: Vector2 = _layout.get("game_offset", Vector2.ZERO)
	var render_scale: float = float(_layout.get("render_scale", 1.0))
	var left_pillar := Rect2i(
		0,
		0,
		maxi(0, int(floorf(game_offset.x)) - 4),
		VIEW_SIZE.y
	)
	var left_pillar_pixels := _count_foreground_pixels(image, left_pillar)
	var boss_pixels := _count_foreground_pixels(
		image,
		_to_screen_rect(Rect2(Vector2(260.0, 0.0), Vector2(240.0, 165.0)))
	)
	var ball_pixels := _count_foreground_pixels(
		image,
		_to_screen_rect(Rect2(BALL_POS - Vector2(70.0, 70.0), Vector2(140.0, 140.0)))
	)
	var before_pixels := _count_color_pixels(
		image,
		game_offset + BEFORE_SENTINEL_POS * render_scale,
		BEFORE_SENTINEL_COLOR
	)
	var after_pixels := _count_color_pixels(
		image,
		game_offset + AFTER_SENTINEL_POS * render_scale,
		AFTER_SENTINEL_COLOR
	)
	var leg_id := str(spec.get("id", "unknown"))
	print(
		"playfield_draw_transform_retention_pixel_smoke: "
		+ "%s left_pillar_pixels=%d boss_pixels=%d ball_pixels=%d before=%d after=%d"
		% [leg_id, left_pillar_pixels, boss_pixels, ball_pixels, before_pixels, after_pixels]
	)
	_expect(
		left_pillar_pixels == 0,
		"%s must leave ZERO boss/ball pixels in the left pillar (got %d)"
		% [leg_id, left_pillar_pixels]
	)
	_expect(boss_pixels > 120, "%s must render visible boss pixels in the playfield" % leg_id)
	_expect(ball_pixels > 120, "%s must render visible ball pixels in the playfield" % leg_id)
	_expect(
		before_pixels > 20 and after_pixels > 20,
		"%s must keep identical transformed placement before and after the boss draw" % leg_id
	)


func _verify_counterproof_signature(image: Image) -> void:
	var game_offset: Vector2 = _layout.get("game_offset", Vector2.ZERO)
	var render_scale: float = float(_layout.get("render_scale", 1.0))
	var left_pillar := Rect2i(
		0,
		0,
		maxi(0, int(floorf(game_offset.x)) - 4),
		VIEW_SIZE.y
	)
	var leaked_pixels := _count_foreground_pixels(image, left_pillar)
	var before_pixels := _count_color_pixels(
		image,
		game_offset + BEFORE_SENTINEL_POS * render_scale,
		BEFORE_SENTINEL_COLOR
	)
	var after_transformed_pixels := _count_color_pixels(
		image,
		game_offset + AFTER_SENTINEL_POS * render_scale,
		AFTER_SENTINEL_COLOR
	)
	var after_raw_pixels := _count_color_pixels(
		image,
		AFTER_SENTINEL_POS,
		AFTER_SENTINEL_COLOR
	)
	_expect(
		leaked_pixels > 400,
		"legacy reset counterproof must expose boss/ball pixels in the left pillar"
	)
	_expect(before_pixels > 20, "counterproof pre-sentinel must retain the outer transform")
	_expect(
		after_transformed_pixels == 0 and after_raw_pixels > 20,
		"legacy reset counterproof must move only the post-boss sentinel to raw coordinates"
	)
	print(
		"playfield_draw_transform_retention_pixel_smoke: "
		+ "counterproof leaked_pixels=%d before=%d after_transformed=%d after_raw=%d"
		% [leaked_pixels, before_pixels, after_transformed_pixels, after_raw_pixels]
	)


func _to_screen_rect(logical_rect: Rect2) -> Rect2i:
	var game_offset: Vector2 = _layout.get("game_offset", Vector2.ZERO)
	var render_scale: float = float(_layout.get("render_scale", 1.0))
	var screen_rect := Rect2(
		game_offset + logical_rect.position * render_scale,
		logical_rect.size * render_scale
	)
	return Rect2i(
		int(floorf(screen_rect.position.x)),
		int(floorf(screen_rect.position.y)),
		int(ceilf(screen_rect.size.x)),
		int(ceilf(screen_rect.size.y))
	)


func _count_foreground_pixels(image: Image, rect: Rect2i) -> int:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var color := image.get_pixel(x, y)
			if color.r + color.g + color.b > 0.42:
				count += 1
	return count


func _count_color_pixels(image: Image, center: Vector2, target: Color) -> int:
	var rect := Rect2i(
		int(roundf(center.x)) - 18,
		int(roundf(center.y)) - 18,
		37,
		37
	).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x, y)
			if (
				absf(color.r - target.r) < 0.12
				and absf(color.g - target.g) < 0.12
				and absf(color.b - target.b) < 0.12
			):
				count += 1
	return count


func _save_capture(image: Image, label: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(_output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := _output_dir.path_join("%s.png" % label)
	var error := image.save_png(path)
	_expect(error == OK, "failed to save capture: %s" % path)
	if error == OK:
		print(
			"playfield_draw_transform_retention_pixel_smoke: capture="
			+ ProjectSettings.globalize_path(path)
		)


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--force-legacy-reset":
			_force_legacy_reset = true
		elif argument.begins_with("--output-dir="):
			_output_dir = argument.trim_prefix("--output-dir=")


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("playfield_draw_transform_retention_pixel_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
