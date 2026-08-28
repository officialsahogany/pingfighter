extends SceneTree

# Windowed Vulkan capture for Feedback10's Guardian extra-active unlock seal.
# The runtime fixture starts from a real zero-active hatch roll, applies the
# production enhancement candidate, then renders the production TAB overlay and
# in-battle Lingpet rail from the resulting two-slot snapshot.

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload(
	"res://scripts/hud/character_info_overlay_lingpet_presenter.gd"
)
const CharacterInfoOverlayValueUtils := preload(
	"res://scripts/hud/character_info_overlay_value_utils.gd"
)
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const Stage1BossSkillHudRenderer := preload(
	"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd"
)

const PET_ID := "maribo"
const TAB_VIEW_SIZE := Vector2i(2020, 1246)
const RAIL_VIEW_SIZE := Vector2i(760, 750)
const CAPTURE_DIR := "res://.godot/codex_captures"
const TAB_CAPTURE_NAME := "feedback10_guardian_active_unlock_tab.png"
const RAIL_CAPTURE_NAME := "feedback10_guardian_active_unlock_rail.png"


class DynamicOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(300.0, 675.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"ball_active": false,
		"ball_pos": Vector2.ZERO,
		"ball_vel": Vector2.ZERO,
		"ball_size": 28.6,
		"special_gauge": 100.0,
		"special_gauge_max": 500.0,
		"lingpet_id": PET_ID,
		"active_lingpet_id": PET_ID,
		"current_lingpet_id": PET_ID,
		"lingpet_state": "companion",
		"lingpet_owned_pet_ids": [PET_ID],
		"owned_lingpet_ids": [PET_ID],
		"owned_ringpet_ids": [PET_ID],
		"lingpet_collection": {PET_ID: true},
		"ringpet_collection": {PET_ID: true},
		"owned_lingpets": {PET_ID: true},
		"owned_ringpets": {PET_ID: true},
		"lingpet_slots": [PET_ID, "", ""],
		"ringpet_slots": [PET_ID, "", ""],
		"lingpet_slot_pet_ids": [PET_ID, "", ""],
		"ringpet_slot_pet_ids": [PET_ID, "", ""],
		"lingpet_active_slot_index": 0,
		"ringpet_active_slot_index": 0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class RuntimeRegistry:
	extends RefCounted

	var runtime: Object = null

	func _init(next_runtime: Object) -> void:
		runtime = next_runtime

	func get_cached_instance(key: String) -> Object:
		return runtime if key == "lingpet_egg_runtime" else null

	func get_instance(key: String) -> Object:
		return get_cached_instance(key)


class TabCanvas:
	extends Node2D

	var overlay: Object = null
	var runtime_owner: Object = null
	var registry: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(TAB_VIEW_SIZE)), Color(0.06, 0.10, 0.18, 1.0))
		draw_rect(Rect2(0.0, 680.0, 2020.0, 566.0), Color(0.03, 0.07, 0.13, 1.0))
		draw_circle(Vector2(570.0, 510.0), 190.0, Color(0.10, 0.42, 0.64, 0.52))
		draw_circle(Vector2(1440.0, 390.0), 130.0, Color(0.62, 0.26, 0.48, 0.38))
		overlay.draw(self, runtime_owner, registry, Vector2(TAB_VIEW_SIZE))


class RailCanvas:
	extends Node2D

	var renderer: Object = Stage1BossSkillHudRenderer.new()
	var entries: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(RAIL_VIEW_SIZE)), Color(0.035, 0.055, 0.085, 1.0))
		for band_index in range(9):
			draw_rect(
				Rect2(0.0, float(band_index) * 84.0, 760.0, 40.0),
				Color(0.075, 0.11, 0.15, 1.0)
			)
		draw_circle(Vector2(330.0, 260.0), 74.0, Color(0.15, 0.48, 0.72, 0.45))
		draw_rect(Rect2(300.0, 675.0, 155.0, 18.0), Color(0.35, 0.95, 0.68, 0.85))
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(
				font,
				Vector2(28.0, 42.0),
				"Guardian active rail / 2 slots",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				18,
				Color(1.0, 0.92, 0.72, 1.0)
			)
		var metrics: Dictionary = renderer.get_debug_card_metrics(80.0)
		var card_size := Vector2(
			maxf(96.0, float(metrics.get("card_width", 96.0))),
			maxf(40.0, float(metrics.get("card_height", 40.0)))
		)
		for index in range(entries.size()):
			var rect := Rect2(Vector2(520.0, 144.0 + float(index) * 82.0), card_size)
			renderer._draw_card(self, rect, entries[index] as Dictionary, 1.0, 0.42)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("feedback10 Guardian active unlock visual QA requires windowed Vulkan")
		quit(1)
		return
	var fixture := _build_fixture()
	var runtime: Object = fixture.get("runtime")
	var owner: Object = fixture.get("owner")
	var registry: Object = fixture.get("registry")
	if runtime == null or owner == null or registry == null:
		quit(1)
		return
	var applied: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK},
		owner,
		registry,
		PET_ID
	)
	if not bool(applied.get("accepted", false)):
		push_error("visual fixture could not apply the production second-active reward")
		quit(1)
		return
	var snapshot: Dictionary = runtime.get_snapshot()
	var entries: Array = LingpetRailCard.build_entries(registry)
	var tab_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(
		owner,
		Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"),
		3
	)
	CharacterInfoOverlayLingpetPresenter.merge_runtime_display_snapshot(tab_snapshot, snapshot)
	var tab_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(
		tab_snapshot,
		Color(0.45, 1.0, 0.68, 1.0)
	)
	if _count_active_specs(tab_specs) != 2 or entries.size() != 2:
		push_error("visual fixture must expose two active cards on both production surfaces")
		quit(1)
		return
	LingpetRailCard.clear_caches()
	for entry_value in entries:
		var entry: Dictionary = entry_value as Dictionary
		var card_path := str(entry.get("card_texture_path", ""))
		var card_texture := ResourceLoader.load(card_path) as Texture2D
		if card_texture == null:
			push_error("visual fixture could not preload rail card art: %s" % card_path)
			quit(1)
			return
		LingpetRailCard._texture_cache[card_path] = card_texture
		if card_path == LingpetRailCard.TEXTURE_PATH:
			LingpetRailCard._texture = card_texture
			LingpetRailCard._texture_loaded = true

	var overlay: Object = CharacterInfoOverlay.new()
	overlay.active = true
	overlay.animation_time = 10.0
	while not overlay.prewarm_lingpet_panel_assets_step([PET_ID]):
		await process_frame
	var capture_root := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(capture_root)
	var tab_path := "%s/%s" % [capture_root, TAB_CAPTURE_NAME]
	var rail_path := "%s/%s" % [capture_root, RAIL_CAPTURE_NAME]
	if not await _capture_tab(overlay, owner, registry, tab_path):
		quit(1)
		return
	if not await _capture_rail(entries, rail_path):
		quit(1)
		return
	print(
		"feedback10_guardian_active_unlock_visual_qa: TAB_ACTIVE_CARDS=2 RAIL_CARDS=2 PRIMARY=%s SECOND=%s"
		% [
			str(snapshot.get("companion_skill_id", "")),
			str(snapshot.get("companion_skill_id_1", "")),
		]
	)
	print(
		"feedback10_guardian_active_unlock_visual_qa: captures=%s,%s"
		% [TAB_CAPTURE_NAME, RAIL_CAPTURE_NAME]
	)
	print("feedback10_guardian_active_unlock_visual_qa: ok")
	quit(0)


func _capture_tab(
	overlay: Object,
	owner: Object,
	registry: Object,
	output_path: String
) -> bool:
	var viewport := SubViewport.new()
	viewport.size = TAB_VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := TabCanvas.new()
	canvas.overlay = overlay
	canvas.runtime_owner = owner
	canvas.registry = registry
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await _wait_render_frames(5)
	var image: Image = viewport.get_texture().get_image()
	var saved := _save_capture(image, output_path, "TAB")
	viewport.queue_free()
	return saved


func _capture_rail(entries: Array, output_path: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = RAIL_VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := RailCanvas.new()
	canvas.entries = entries
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await _wait_render_frames(5)
	var image: Image = viewport.get_texture().get_image()
	var saved := _save_capture(image, output_path, "rail")
	viewport.queue_free()
	return saved


func _wait_render_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await process_frame


func _save_capture(image: Image, output_path: String, label: String) -> bool:
	if image == null or image.is_empty():
		push_error("%s capture returned an empty viewport image" % label)
		return false
	if image.save_png(output_path) != OK:
		push_error("%s capture could not be saved: %s" % [label, output_path])
		return false
	print("capture: %s" % output_path)
	return true


func _build_fixture() -> Dictionary:
	var hatch_loadout := _find_zero_active_hatch_loadout()
	if hatch_loadout.is_empty():
		push_error("visual fixture could not find a real zero-active hatch roll")
		return {}
	var owner := DynamicOwner.new()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := RuntimeRegistry.new(runtime)
	if not runtime.debug_grant_and_activate_pet(
		PET_ID,
		owner,
		false,
		str(hatch_loadout.get("active_skill_id", "")),
		str(hatch_loadout.get("passive_skill_id", "")),
		registry,
		int(hatch_loadout.get("active_skill_level", 0)),
		int(hatch_loadout.get("passive_skill_level", 0))
	):
		push_error("visual fixture could not activate the hatch loadout")
		return {}
	runtime._loadout_state.set_skip_unlock_reconcile(false)
	runtime._loadout_state.invalidate_runtime_and_snapshot_cache(runtime._snapshot_builder)
	runtime.update(0.0, owner, registry)
	return {"owner": owner, "runtime": runtime, "registry": registry}


func _find_zero_active_hatch_loadout() -> Dictionary:
	for seed_value in range(1, 4097):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var loadout: Dictionary = LingpetCatalog.pick_skill_loadout(PET_ID, rng)
		if (
			str(loadout.get("active_skill_id", "")) == ""
			and str(loadout.get("passive_skill_id", "")) != ""
		):
			return loadout
	return {}


func _count_active_specs(specs: Array) -> int:
	var count := 0
	for value in specs:
		if value is Dictionary and str((value as Dictionary).get("badge", "")) == "A":
			count += 1
	return count
