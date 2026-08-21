extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDebugPicker := preload("res://scripts/hud/runtime_perk_debug_picker.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const VIEW_SIZE := Vector2i(1180, 720)
const CAPTURE_PATH := "res://.tmp/mugong_icon_debug_codex_qa.png"
const CAPTURE_IDS := ["star_detector", "reinforced_boomerang_gauntlet", "rainbow_fur_glove"]


class CaptureCatalog:
	extends RefCounted

	var entries: Array = []

	func get_debug_perk_entries(_character_type: String = "") -> Array:
		return entries


class CaptureOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_levels := {
		"star_detector": 1,
		"reinforced_boomerang_gauntlet": 2,
		"rainbow_fur_glove": 3,
	}


class CaptureRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


class CodexProbe:
	extends Control

	var picker: Object = null
	var capture_owner: Object = null
	var registry: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.010, 0.014, 0.022, 1.0))
		picker.draw(self, capture_owner, registry, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("mugong_icon_debug_codex_visual_qa: capture skipped under headless display server")
		print("mugong_icon_debug_codex_visual_qa: ok")
		quit(0)
		return
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var runtime_catalog := RuntimePerkCatalog.new()
	var capture_catalog := CaptureCatalog.new()
	for perk_id in CAPTURE_IDS:
		var entry: Dictionary = runtime_catalog.get_perk_data(perk_id).duplicate(true)
		if entry.is_empty():
			push_error("Mugong debug-codex capture needs catalog data for %s" % perk_id)
			LanguageSettings.set_test_locale_override("")
			quit(1)
			return
		entry["id"] = perk_id
		entry["debug_group"] = "common"
		capture_catalog.entries.append(entry)

	var icon_renderer := RuntimePerkIconRenderer.new()
	var owner := CaptureOwner.new()
	var registry := CaptureRegistry.new()
	registry.instances = {
		"runtime_perk_catalog": capture_catalog,
		"runtime_perk_icon_renderer": icon_renderer,
	}
	var picker := RuntimePerkDebugPicker.new()
	picker.open = true
	picker.selected_tab_index = 4
	picker.prewarm_assets(capture_catalog, owner, icon_renderer)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := CodexProbe.new()
	probe.size = Vector2(VIEW_SIZE)
	probe.picker = picker
	probe.capture_owner = owner
	probe.registry = registry
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save the production Mugong debug-codex capture")
		LanguageSettings.set_test_locale_override("")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	LanguageSettings.set_test_locale_override("")
	print("mugong_icon_debug_codex_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
