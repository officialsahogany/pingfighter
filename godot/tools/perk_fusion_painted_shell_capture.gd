extends SceneTree

const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")

const OUTPUT_DIR := "res://../images/perk_fusion_hwangyeok_jumul_reskin/qa"

var _renderer: Object


class CatalogStub:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == "iron_body_art":
			return {"name": "잔영호법"}
		if perk_id == "gravity_sword_art":
			return {"name": "산화수"}
		return {"name": perk_id.replace("_", " ").capitalize()}


class CaptureCanvas:
	extends Control

	var renderer: Object
	var snapshot: Dictionary
	var catalog: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.12, 0.17), true)
		renderer.draw(self, snapshot, catalog, size)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("perk_fusion_painted_shell_capture requires a real renderer")
		quit(1)
		return
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if mkdir_error != OK:
		push_error("Could not create painted-shell QA output directory: %s" % output_absolute)
		quit(1)
		return
	_renderer = PerkFusionOverlayRenderer.new()
	_renderer.prewarm_assets()
	var failures: Array[String] = []
	await _capture("fusion_modal_runtime_confirm_760.png", Vector2i(760, 750), _confirm_snapshot(), failures)
	await _capture("fusion_modal_runtime_confirm_420.png", Vector2i(420, 560), _confirm_snapshot(), failures)
	var cached_textures: Dictionary = _renderer._textures.duplicate()
	_renderer._textures.clear()
	await _capture("fusion_modal_runtime_fallback_760.png", Vector2i(760, 750), _confirm_snapshot(), failures)
	_renderer._textures = cached_textures
	if failures.is_empty():
		print("perk_fusion_painted_shell_capture: ok (%s)" % output_absolute)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _capture(file_name: String, viewport_size: Vector2i, snapshot: Dictionary, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CaptureCanvas.new()
	canvas.renderer = _renderer
	canvas.snapshot = snapshot
	canvas.catalog = CatalogStub.new()
	canvas.size = Vector2(viewport_size)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.is_empty() or image.get_size() != viewport_size:
		failures.append("%s returned invalid image dimensions" % file_name)
	else:
		var save_error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
		if save_error != OK:
			failures.append("%s save failed: %d" % [file_name, save_error])
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _confirm_snapshot() -> Dictionary:
	return {
		"phase": "confirm",
		"selected_source_ids": ["iron_body_art", "gravity_sword_art"],
		"source_previews": [
			{"perk_id": "iron_body_art", "base_level": 5, "effective_level": 5, "options": []},
			{
				"perk_id": "gravity_sword_art",
				"base_level": 5,
				"effective_level": 5,
				"options": [
					{"key": "damage", "value": 18.8, "polarity": "forward"},
					{"key": "cooldown", "value": 4.8, "polarity": "forward"},
					{"key": "duration", "value": 9.0, "polarity": "forward"},
				],
			},
		],
		"outcome_preview": {
			"weights": {"success": 0.55, "side_effect": 0.25, "byproduct": 0.20},
		},
	}
