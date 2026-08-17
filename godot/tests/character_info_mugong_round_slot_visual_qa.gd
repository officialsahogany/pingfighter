extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const VIEW_SIZE := Vector2i(1180, 280)
const PANEL_RECT := Rect2(20.0, 18.0, 1140.0, 238.0)
const CAPTURE_PATH := "res://.tmp/character_info_mugong_round_slot_qa.png"
const LEVELS := {
	"item_luck": 5,
	"common_bulk_up": 5,
	"common_training": 5,
	"chargebag": 4,
	"common_swiftness": 3,
	"sensor": 2,
	"dash_module_control": 1,
}


class FakeRegistry:
	extends RefCounted

	var state: Object = null

	func _init(next_state: Object) -> void:
		state = next_state

	func get_instance(key: String) -> Object:
		return state if key == "runtime_perk_state" else null


class PanelProbe:
	extends Control

	var overlay: Object = null
	var catalog: Object = null
	var icon_renderer: Object = null
	var runtime_state: Object = null
	var registry: Object = null
	var snapshot: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.025, 0.045), true)
		overlay._draw_perk_grid(
			self,
			null,
			registry,
			PANEL_RECT,
			ThemeDB.fallback_font,
			Vector2(-100.0, -100.0),
			{},
			runtime_state,
			icon_renderer,
			snapshot,
			catalog,
			[]
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("character_info_mugong_round_slot_visual_qa: capture skipped under headless display server")
		print("character_info_mugong_round_slot_visual_qa: ok")
		PerkConversionFlags.debug_set_enabled(false)
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = LEVELS.duplicate(true)
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["meridian_expand"]},
		catalog
	)
	if record.is_empty():
		push_error("Failed to build the meridian-expansion visual QA fixture")
		PerkConversionFlags.debug_set_enabled(false)
		quit(1)
		return
	var probe := PanelProbe.new()
	probe.size = VIEW_SIZE
	probe.overlay = CharacterInfoOverlay.new()
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	probe.runtime_state = state
	probe.registry = FakeRegistry.new(state)
	probe.snapshot = state.get_snapshot()
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save the production character-info Mugong slot capture")
		PerkConversionFlags.debug_set_enabled(false)
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	PerkConversionFlags.debug_set_enabled(false)
	print("character_info_mugong_round_slot_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
