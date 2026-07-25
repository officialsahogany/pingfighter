extends SceneTree

# Stage 8 미노타우로스 Slice 1 visual QA: draws the code-native placeholder
# pillar background + boss silhouette into a real SubViewport, saves a PNG for
# pixel review, and asserts the placeholder actually paints pixels (state
# smokes stay green on pixel-only defects — this is the pixel seal).
# Run WINDOWED (non-headless) so the viewport renders real pixels.

const Stage8MinotaurPillarBackground := preload("res://scripts/stages/stage8/stage8_minotaur_pillar_background.gd")
const Stage8MinotaurBossActorRenderer := preload("res://scripts/stages/stage8/stage8_minotaur_boss_actor_renderer.gd")

# Realistic side-heavy letterbox (scaled from the real 2020x1246 / game 760x750
# layout) so the Parthenon side columns + field composition can be pixel-QA'd.
const VIEW_SIZE := Vector2i(1440, 888)
const GAME_OFFSET := Vector2(306.0, 36.0)
const GAME_SIZE := Vector2(828.0, 817.0)
const DEFAULT_OUT := "user://stage8_slice1_placeholder.png"

var _failures: Array[String] = []


class Stage8Slice1DrawProbe:
	extends Node2D

	var pillar_background: Object = null
	var boss_renderer: Object = null
	var actor_context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if pillar_background != null:
			pillar_background.draw(self, Vector2(VIEW_SIZE), GAME_OFFSET, GAME_SIZE, GAME_SIZE.x, null, 1.0)
			if pillar_background.has_method("draw_pillar_background_overlay"):
				pillar_background.draw_pillar_background_overlay(self, Vector2(VIEW_SIZE), GAME_OFFSET, GAME_SIZE, GAME_SIZE.x, null, 1.0)
		if boss_renderer != null:
			boss_renderer.draw(self, actor_context, Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := Stage8Slice1DrawProbe.new()
	probe.pillar_background = Stage8MinotaurPillarBackground.new()
	probe.boss_renderer = Stage8MinotaurBossActorRenderer.new()
	# Prewarm boss sheets + pillar/field art so the real-texture branches (not the
	# code-native placeholders) render.
	if probe.boss_renderer.has_method("prewarm_assets"):
		probe.boss_renderer.prewarm_assets()
	if probe.pillar_background.has_method("prewarm_assets"):
		probe.pillar_background.prewarm_assets()
	# Boss centered on the field (game-space -> the probe draws boss at raw pos).
	probe.actor_context = {
		"current_stage": 8,
		"boss_pos": Vector2(GAME_OFFSET.x + GAME_SIZE.x * 0.5 - 50.0, GAME_OFFSET.y + 40.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"boss_paddle_shrink_scale": 1.0,
	}
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame in range(6):
		await process_frame

	_expect(probe.draw_count > 0, "Slice 1 placeholder pillar + boss should execute inside a real CanvasItem draw pass")

	var headless := OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0
	if not headless:
		var image: Image = viewport.get_texture().get_image()
		_expect(image != null and not image.is_empty(), "windowed visual QA should capture the Slice 1 viewport")
		if image != null and not image.is_empty():
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			var out_path: String = DEFAULT_OUT
			var user_args: PackedStringArray = OS.get_cmdline_user_args()
			if user_args.size() > 0 and user_args[0] != "":
				out_path = user_args[0]
			var save_err: int = image.save_png(out_path)
			_expect(save_err == OK, "should save the Slice 1 placeholder PNG to %s (err %d)" % [out_path, save_err])
			print("stage8_slice1_visual: saved ", ProjectSettings.globalize_path(out_path))
			var field_center := Vector2i(int(GAME_OFFSET.x + GAME_SIZE.x * 0.5), int(GAME_OFFSET.y + GAME_SIZE.y * 0.5))
			var field_px: Color = image.get_pixelv(field_center)
			# Parthenon field (marble court) art fills the game canvas center.
			_expect(field_px.a > 0.9, "Parthenon field art should fill the center game canvas")
			# Left letterbox carries the Parthenon column chrome (opaque, distinct from field).
			var side_px: Color = image.get_pixelv(Vector2i(int(GAME_OFFSET.x * 0.5), field_center.y))
			_expect(side_px.a > 0.5 and side_px != field_px, "left letterbox should render the Parthenon side column art")
			# Boss sprite near its anchor (top-center of the field).
			var boss_x := int(GAME_OFFSET.x + GAME_SIZE.x * 0.5)
			var boss_hit := false
			for sy in range(int(GAME_OFFSET.y) + 20, int(GAME_OFFSET.y) + 240):
				if image.get_pixel(boss_x, sy).a > 0.5 and image.get_pixel(boss_x, sy) != field_px:
					boss_hit = true
					break
			_expect(boss_hit, "minotaur boss sprite should paint pixels near the boss anchor")
	else:
		print("stage8_slice1_visual: headless run — pixel capture skipped")

	viewport.queue_free()
	if _failures.is_empty():
		print("stage8_minotaur_slice1_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
