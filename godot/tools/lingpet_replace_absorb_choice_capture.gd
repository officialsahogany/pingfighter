extends SceneTree

# Windowed Vulkan pixel-QA harness for the one-guardian Replace / Absorb modal.
# Run from godot/ with --rendering-method mobile, never --headless.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetOverflowChoiceOverlayHost := preload(
	"res://scripts/hud/lingpet_overflow_choice_overlay_host.gd"
)
const OUT_DIR := "D:/tmp/bosspong_guardian_roster_qa"
const VIEW_SIZE := Vector2i(760, 750)


class FakeRuntime:
	extends RefCounted
	var snapshot: Dictionary = {}

	func is_overflow_choice_active() -> bool:
		return true

	func get_overflow_choice_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class ModalCanvas:
	extends Node2D
	var host: Object
	var runtime: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.045, 0.07, 0.105), true)
		draw_circle(Vector2(118.0, 245.0), 142.0, Color(0.08, 0.42, 0.43, 0.38))
		draw_circle(Vector2(655.0, 170.0), 118.0, Color(0.42, 0.17, 0.36, 0.32))
		draw_rect(Rect2(0.0, 620.0, 760.0, 130.0), Color(0.018, 0.035, 0.055), true)
		host.draw(self, runtime, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("lingpet_replace_absorb_choice_capture requires a windowed renderer")
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
	var host := LingpetOverflowChoiceOverlayHost.new()
	host.prewarm_assets()
	var skill: Dictionary = LingpetCatalog.get_active_skill_pool("lunabi")[0]
	var runtime := FakeRuntime.new()
	runtime.snapshot = {
		"active": true,
		"pending_pet_id": "lunabi",
		"pending_display_name": LingpetCatalog.get_display_name("lunabi"),
		"absorb_only": false,
		"replacement_skill_name": str(skill.get("name", "")),
		"replacement_skill_icon_path": str(skill.get("icon_texture_path", "")),
		"slots": [{
			"slot_index": 0,
			"pet_id": "maribo",
			"display_name": LingpetCatalog.get_display_name("maribo"),
			"active": true,
		}],
		"active_slot_index": 0,
	}
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := ModalCanvas.new()
	canvas.host = host
	canvas.runtime = runtime
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/guardian_replace_absorb_choice.png" % OUT_DIR
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		push_error("failed to save capture: %s" % output_path)
		quit(1)
		return
	if not FileAccess.file_exists(output_path) or FileAccess.get_file_as_bytes(output_path).is_empty():
		push_error("capture missing or empty: %s" % output_path)
		quit(1)
		return
	print("[LingpetRosterCapture] %s" % output_path)
	print("[LingpetRosterCapture] renderer=%s" % RenderingServer.get_current_rendering_method())
	quit(0)
