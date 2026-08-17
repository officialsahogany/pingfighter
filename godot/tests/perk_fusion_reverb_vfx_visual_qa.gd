extends SceneTree

const PerkFusionReverbVfxState := preload("res://scripts/characters/perk_fusion_reverb_vfx_state.gd")

const VIEW_SIZE := Vector2i(760, 750)
const CAPTURE_PATH := "res://.tmp/perk_fusion_reverb_vfx_visual_qa.png"
const PLAYER_PREVIEW_PATH := "res://assets/sprites/smasher_current_idle.png"


class OwnerFixture:
	extends RefCounted

	var player_pos := Vector2(205.0, 672.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class EffectProbe:
	extends Node2D

	var state: Object = PerkFusionReverbVfxState.new()
	var player_fixture := OwnerFixture.new()
	var player_texture: Texture2D = load(PLAYER_PREVIEW_PATH)
	var draw_calls := 0

	func prepare() -> void:
		state.trigger()
		state.advance(1.0 / 60.0, player_fixture, true)
		for _step_index in range(5):
			player_fixture.player_pos.x += 48.0
			state.advance(0.072, player_fixture, true)
		state.trigger()
		state.advance(0.02, player_fixture, true)

	func _draw() -> void:
		draw_calls += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.010, 0.018, 0.038), true)
		for x in range(0, VIEW_SIZE.x, 40):
			draw_line(Vector2(float(x), 0.0), Vector2(float(x), float(VIEW_SIZE.y)), Color(0.17, 0.28, 0.42, 0.10), 1.0)
		for y in range(30, VIEW_SIZE.y, 40):
			draw_line(Vector2(0.0, float(y)), Vector2(float(VIEW_SIZE.x), float(y)), Color(0.17, 0.28, 0.42, 0.08), 1.0)
		var player_size := Vector2(player_fixture.player_paddle_width, player_fixture.player_paddle_height)
		var player_rect := Rect2(player_fixture.player_pos, player_size)
		if player_texture != null:
			var texture_size := player_texture.get_size()
			var player_sprite_rect := Rect2(
				Vector2(player_rect.get_center().x - texture_size.x * 0.5, player_rect.end.y - texture_size.y + 6.0),
				texture_size
			)
			draw_texture_rect(player_texture, player_sprite_rect, false)
		else:
			draw_rect(player_rect, Color(0.14, 0.20, 0.34, 1.0), true)
			draw_rect(player_rect, Color(0.84, 0.92, 1.0, 0.88), false, 2.0, true)
		state.draw(self, Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_reverb_vfx_visual_qa: capture skipped under headless display server")
		print("perk_fusion_reverb_vfx_visual_qa: ok")
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := EffectProbe.new()
	viewport.add_child(probe)
	probe.prepare()
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if probe.draw_calls <= 0:
		push_error("Reverb visual QA probe did not draw")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Reverb visual QA capture failed")
		quit(1)
		return
	var accent_pixels := 0
	for y in range(620, image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if (color.g > 0.62 and color.b > 0.66) or (color.r > 0.72 and color.g > 0.48 and color.b < 0.48):
				accent_pixels += 1
	if accent_pixels < 700:
		push_error("Reverb visual QA did not render enough cyan/gold accent pixels: %d" % accent_pixels)
		quit(1)
		return
	print("perk_fusion_reverb_vfx_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
