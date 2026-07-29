extends SceneTree

# Windowed Vulkan pixel-QA harness for the compact Guardian Enhancement panel.
# Run from godot/ with --rendering-method mobile (Vulkan), never --headless.

const LingpetGuardianEnhanceCutinOverlayHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const OUT_DIR := "D:/tmp/bosspong_guardian_enhance_qa"
const VIEW_SIZE := Vector2i(760, 750)


class FakeRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_guardian_enhance_cutin_active() -> bool:
		return true

	func get_guardian_enhance_cutin_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class PanelCanvas:
	extends Node2D

	var host: Object
	var runtime: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.055, 0.085, 0.12), true)
		draw_circle(Vector2(150.0, 260.0), 132.0, Color(0.11, 0.31, 0.42, 0.52))
		draw_circle(Vector2(650.0, 190.0), 95.0, Color(0.34, 0.16, 0.39, 0.40))
		draw_rect(Rect2(0.0, 610.0, 760.0, 140.0), Color(0.025, 0.05, 0.07), true)
		host.draw(self, runtime, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("guardian_enhance_compact_panel_capture requires a windowed renderer")
		quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Vulkan mobile renderer required, got: %s" % RenderingServer.get_current_rendering_method())
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUT_DIR) != OK:
		push_error("failed to create capture directory: %s" % OUT_DIR)
		quit(1)
		return
	var host := LingpetGuardianEnhanceCutinOverlayHost.new()
	host.prewarm_assets()
	if not bool(host.prewarm_pet_assets_step("maribo", true)):
		push_error("failed to synchronously prewarm Maribo companion reaction")
		quit(1)
		return
	var contract: Dictionary = host.get_animation_contract("maribo")
	var level_icon_path := str(LingpetCatalog.get_active_skill_pool("milkring")[1].get("icon_texture_path", ""))
	var unlock_icon_path := str(LingpetCatalog.get_passive_skill_pool("maribo")[0].get("icon_texture_path", ""))
	var shots := [
		{
			"name": "guardian_enhance_skill_level_result",
			"snapshot": {
				"active": true,
				"phase": "reaction",
				"pet_id": "maribo",
				"roll_progress": 1.0,
				"animation_frame": 28,
				"animation_contract": contract,
				"feedback_text": "밀크 발사 Lv.2 → Lv.3",
				"result": {"result_detail": {"kind": "skill_level", "icon_texture_path": level_icon_path}},
			},
		},
		{
			"name": "guardian_enhance_skill_unlock_result",
			"snapshot": {
				"active": true,
				"phase": "reaction",
				"pet_id": "maribo",
				"roll_progress": 1.0,
				"reaction_active": true,
				"animation_frame": 37,
				"animation_contract": contract,
				"feedback_text": "공명 증폭 해금",
				"result": {"result_detail": {"kind": "skill_unlock", "icon_texture_path": unlock_icon_path}},
			},
		},
	]
	for shot_value: Variant in shots:
		var shot: Dictionary = shot_value as Dictionary
		var viewport := SubViewport.new()
		viewport.size = VIEW_SIZE
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var runtime := FakeRuntime.new()
		runtime.snapshot = (shot.get("snapshot", {}) as Dictionary).duplicate(true)
		var canvas := PanelCanvas.new()
		canvas.host = host
		canvas.runtime = runtime
		viewport.add_child(canvas)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var output_path := "%s/%s.png" % [OUT_DIR, str(shot.get("name", "capture"))]
		if image == null or image.is_empty() or image.save_png(output_path) != OK:
			push_error("failed to save capture: %s" % output_path)
			quit(1)
			return
		if not FileAccess.file_exists(output_path) or FileAccess.get_file_as_bytes(output_path).is_empty():
			push_error("capture missing or empty: %s" % output_path)
			quit(1)
			return
		print("[GuardianEnhanceCompactCapture] %s" % output_path)
		root.remove_child(viewport)
		viewport.queue_free()
		await process_frame
	print("[GuardianEnhanceCompactCapture] renderer=%s" % RenderingServer.get_current_rendering_method())
	quit(0)
