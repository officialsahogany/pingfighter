extends SceneTree

const BallRenderer := preload("res://scripts/ball/ball_renderer.gd")

const VIEW_SIZE := Vector2i(520, 300)
const NORMAL_POS := Vector2(160.0, 150.0)
const THUNDER_DRIVE_POS := Vector2(360.0, 150.0)
const CAPTURE_PATH := "res://.tmp/perk_fusion_thunder_drive_ball_visual_qa.png"


class BallVisualProbe:
	extends Node2D

	var renderer: Object = BallRenderer.new()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.008, 0.012, 0.035), true)
		for line_index in range(7):
			var y: float = 30.0 + float(line_index) * 40.0
			draw_line(Vector2(24.0, y), Vector2(VIEW_SIZE.x - 24.0, y), Color(0.22, 0.28, 0.52, 0.12), 1.0)
		renderer.draw_current(
			self,
			NORMAL_POS,
			{
				"ball_vel": Vector2(18.0, -10.0),
				"effect_lod_scale": 1.0,
			},
			null,
			false
		)
		renderer.draw_current(
			self,
			THUNDER_DRIVE_POS,
			{
				"ball_vel": Vector2(32.4, -18.0),
				"effect_lod_scale": 1.0,
				"perk_fusion_thunder_drive_active": true,
				"node_fx_layout": {
					"screen_pos": THUNDER_DRIVE_POS,
					"render_scale": 1.0,
				},
			},
			null,
			true
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir: String = ProjectSettings.globalize_path("res://.tmp")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	var probe := BallVisualProbe.new()
	viewport.add_child(probe)
	probe.renderer.prewarm_assets()
	probe.renderer.prewarm_runtime_nodes(probe)
	probe.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var error: Error = image.save_png(CAPTURE_PATH)
	if error != OK:
		push_error("Failed to save Thunderbolt Drive ball visual QA capture: %s" % CAPTURE_PATH)
		quit(1)
		return
	probe.renderer.clear()
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	print("perk_fusion_thunder_drive_ball_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
