extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkFusionOverlayRenderer := preload("res://scripts/hud/perk_fusion_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDisplayProjectionState := preload("res://scripts/characters/runtime_perk_display_projection_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const VIEW_SIZE := Vector2i(1024, 925)
const CAPTURE_PATH := "res://.tmp/perk_fusion_confirm_readability_qa.png"


class FusionConfirmProbe:
	extends Control

	var renderer: Object = null
	var snapshot: Dictionary = {}
	var catalog: Object = null
	var icon_renderer: Object = null

	func _draw() -> void:
		renderer.draw(self, snapshot, catalog, Vector2(size), icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		print("perk_fusion_confirm_readability_visual_qa: capture skipped under headless display server")
		print("perk_fusion_confirm_readability_visual_qa: ok")
		quit(0)
		return
	PerkConversionFlags.debug_set_enabled(true)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = {
		"dowsing_goggles": 3,
		"dash_jump": 5,
		"item_polish": 3,
	}
	var catalog := RuntimePerkCatalog.new()
	var snapshot: Dictionary = RuntimePerkDisplayProjectionState.new().merge_perk_fusion_modal_preview(
		runtime_state,
		{
			"phase": "confirm",
			"selected_source_ids": ["dowsing_goggles", "dash_jump"],
		},
		catalog
	)
	var renderer := PerkFusionOverlayRenderer.new()
	renderer.prewarm_assets()
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var probe := FusionConfirmProbe.new()
	probe.size = Vector2(VIEW_SIZE)
	probe.renderer = renderer
	probe.snapshot = snapshot
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save the perk-fusion confirm readability capture")
		quit(1)
		return
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)
	print("perk_fusion_confirm_readability_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
