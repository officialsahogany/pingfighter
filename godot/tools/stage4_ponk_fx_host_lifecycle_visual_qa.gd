extends SceneTree

const BattleSceneMatchFlowDriver := preload("res://scripts/core/battle_scene_match_flow_driver.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")

const VIEW_SIZE := Vector2i(760, 750)
const DEFAULT_OUTPUT_DIR := "res://.godot/codex_artifacts/feedback10_ponk_fx_lifecycle"
const RESIDUE_PIXEL_MIN := 1000


class MapCanvas:
	extends Node2D

	var map_mode := false

	func _draw() -> void:
		if not map_mode:
			draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.09, 0.055, 0.10, 1.0))
			draw_rect(Rect2(22.0, 22.0, 716.0, 706.0), Color(0.18, 0.09, 0.16, 1.0), false, 5.0)
			draw_string(ThemeDB.fallback_font, Vector2(252.0, 58.0), "STAGE 4 · PONK AWAKENED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.82, 0.48))
			return
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.035, 0.075, 0.085, 1.0))
		draw_rect(Rect2(24.0, 24.0, 712.0, 702.0), Color(0.11, 0.18, 0.17, 1.0), false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(246.0, 62.0), "TOWER NODE MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, Color(0.78, 0.95, 0.84))
		var nodes := [
			Vector2(380.0, 132.0),
			Vector2(270.0, 252.0),
			Vector2(490.0, 252.0),
			Vector2(220.0, 396.0),
			Vector2(380.0, 396.0),
			Vector2(540.0, 396.0),
			Vector2(300.0, 548.0),
			Vector2(460.0, 548.0),
		]
		for index: int in range(nodes.size() - 1):
			draw_line(nodes[index], nodes[index + 1], Color(0.38, 0.62, 0.54, 0.78), 5.0, true)
		for index: int in range(nodes.size()):
			var radius := 24.0 if index == 0 else 19.0
			draw_circle(nodes[index], radius + 5.0, Color(0.05, 0.10, 0.10, 1.0))
			draw_circle(nodes[index], radius, Color(0.35, 0.70, 0.55, 1.0))
			draw_circle(nodes[index], radius - 8.0, Color(0.88, 0.78, 0.38, 1.0))


class FakeTowerFlowOwner:
	extends RefCounted

	var begin_calls := 0

	func begin_vertical_slice(
		_owner: Object,
		_finish_callback: Callable,
		_context: Dictionary = {}
	) -> bool:
		begin_calls += 1
		return true


class FakeRegistry:
	extends RefCounted

	var flow_owner := FakeTowerFlowOwner.new()

	func get_instance(key: String) -> Object:
		return flow_owner if key == "tower_ascent_flow_owner" else null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage4_ponk_fx_host_lifecycle_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage4_ponk_fx_host_lifecycle_visual_qa requires a Vulkan rendering device")
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		_fail("stage4_ponk_fx_host_lifecycle_visual_qa requires Vulkan mobile")
		return

	var label := "candidate"
	var expect_residue := false
	var output_dir := ProjectSettings.globalize_path(DEFAULT_OUTPUT_DIR)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			label = argument.substr("--label=".length()).strip_edges()
		elif argument.begins_with("--expect-residue="):
			expect_residue = argument.substr("--expect-residue=".length()).to_lower() == "true"
		elif argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if label.is_empty():
		_fail("capture label must not be empty")
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("capture directory creation failed: %s" % output_dir)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := MapCanvas.new()
	viewport.add_child(canvas)
	var aura := Stage4PonkAwakenAuraFxHost.new()
	aura.name = "PonkAwakenAuraFxHost"
	canvas.add_child(aura)
	aura.prewarm_runtime_nodes()
	aura.sync_state({
		"active": true,
		"intensity": 1.0,
		"boss_center": Vector2(380.0, 180.0),
		"elapsed": 8.75,
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
		"enraged": true,
	}, true)
	if not aura.visible or not aura.has_runtime_assets():
		_fail("production Ponk awaken aura did not become visibly active")
		return

	await _settle_frames(8)
	var registry := FakeRegistry.new()
	var started := BattleSceneMatchFlowDriver.new()._try_start_tower_ascent_vertical_slice(
		registry,
		Callable(),
		canvas
	)
	if not started or registry.flow_owner.begin_calls != 1:
		_fail("production Tower map transition fixture did not start exactly once")
		return
	canvas.map_mode = true
	canvas.queue_redraw()
	await _settle_frames(4)

	var transition_image := _capture_viewport(viewport)
	if transition_image == null:
		_fail("transition capture returned an invalid image")
		return
	var transition_path := output_dir.path_join("%s_node_map_transition.png" % label)
	if transition_image.save_png(transition_path) != OK:
		_fail("transition capture save failed: %s" % transition_path)
		return

	aura.set_active(false)
	await _settle_frames(3)
	var clean_image := _capture_viewport(viewport)
	if clean_image == null:
		_fail("clean reference capture returned an invalid image")
		return
	var clean_path := output_dir.path_join("%s_node_map_clean_reference.png" % label)
	if clean_image.save_png(clean_path) != OK:
		_fail("clean reference save failed: %s" % clean_path)
		return

	var changed_pixels := _count_changed_pixels(transition_image, clean_image)
	if expect_residue and changed_pixels < RESIDUE_PIXEL_MIN:
		_fail("expected the unfixed transition to retain visible aura residue, changed_pixels=%d" % changed_pixels)
		return
	if not expect_residue and changed_pixels != 0:
		_fail("fixed transition must match the clean node-map reference, changed_pixels=%d" % changed_pixels)
		return

	print("stage4_ponk_fx_host_lifecycle_visual_qa: renderer=%s" % RenderingServer.get_current_rendering_method())
	print("stage4_ponk_fx_host_lifecycle_visual_qa: label=%s expect_residue=%s changed_pixels=%d" % [label, expect_residue, changed_pixels])
	print("stage4_ponk_fx_host_lifecycle_visual_qa: transition=%s" % transition_path)
	print("stage4_ponk_fx_host_lifecycle_visual_qa: clean_reference=%s" % clean_path)
	print("stage4_ponk_fx_host_lifecycle_visual_qa: ok")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture_viewport(viewport: SubViewport) -> Image:
	RenderingServer.force_draw(false)
	var texture := viewport.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _count_changed_pixels(first: Image, second: Image) -> int:
	var first_bytes := first.get_data()
	var second_bytes := second.get_data()
	if first_bytes.size() != second_bytes.size():
		return VIEW_SIZE.x * VIEW_SIZE.y
	var changed := 0
	for byte_index: int in range(0, first_bytes.size(), 4):
		if (
			first_bytes[byte_index] != second_bytes[byte_index]
			or first_bytes[byte_index + 1] != second_bytes[byte_index + 1]
			or first_bytes[byte_index + 2] != second_bytes[byte_index + 2]
			or first_bytes[byte_index + 3] != second_bytes[byte_index + 3]
		):
			changed += 1
	return changed


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
