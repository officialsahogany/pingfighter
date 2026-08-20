extends SceneTree

const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemResourceBonusRuntime := preload("res://scripts/items/mythic_item_resource_bonus_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const DEFAULT_OUTPUT_DIR := "res://.godot/codex_artifacts/training_card_stat_preview"
const VISIBLE_DRAW_MSEC := 100
const HIDDEN_DRAW_MSEC := 500
const PIXEL_DIFF_THRESHOLD := 0.055


class CaptureOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)
	var special_gauge := 250.0
	var special_gauge_max := 500.0
	var active_item_slots: Array = []


class CaptureRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


class CaptureMythicRuntime:
	extends RefCounted

	var runtime_perk_state_ref: Object = null
	var synced_special_gauge_max := 500.0
	var synced_special_gauge_unblessed_max := 500.0
	var synced_angel_gauge_multiplier := 1.0
	var _resource_bonus := MythicItemResourceBonusRuntime.new()
	var _owner_syncer := MythicItemOwnerSyncer.new()

	func refresh_runtime_perk_scaling(owner: Object, registry: Object) -> void:
		runtime_perk_state_ref = registry.get_instance("runtime_perk_state") if registry != null else null
		_owner_syncer.sync_fuel_pouch_gauge_max(
			self,
			owner,
			{"base_special_gauge_max": CharacterInfoOverlayState.SPECIAL_GAUGE_MAX}
		)

	func get_effective_special_gauge_max(base_max: float) -> float:
		return _resource_bonus.get_effective_special_gauge_max(self, base_max)

	func calculate_bluetooth_ring_gauge_charge(base_charge: float) -> float:
		return _resource_bonus.calculate_bluetooth_ring_gauge_charge(self, base_charge)

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key) if owner != null else null
		return fallback if value == null else value


class PreviewCanvas:
	extends Node2D

	var renderer: Object
	var runtime_state: Object
	var catalog: Object
	var icon_renderer: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.13, 0.14, 0.17, 1.0))
		renderer.draw(
			self,
			runtime_state,
			catalog,
			Vector2(VIEW_SIZE),
			icon_renderer
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("training_card_stat_preview_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("training_card_stat_preview_visual_qa requires a Vulkan rendering device")
		quit(1)
		return
	PerkConversionFlags.debug_set_enabled(true)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var output_dir := ProjectSettings.globalize_path(DEFAULT_OUTPUT_DIR)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("training preview capture directory creation failed: %s" % output_dir)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var fixture: Dictionary = _build_fixture("physique_move_speed", false)
	var canvas := PreviewCanvas.new()
	canvas.renderer = fixture["renderer"]
	canvas.runtime_state = fixture["state"]
	canvas.catalog = RuntimePerkCatalog.new()
	canvas.icon_renderer = fixture["icon_renderer"]
	viewport.add_child(canvas)
	var state: Object = fixture["state"]
	var renderer: Object = fixture["renderer"]
	var card_rect: Rect2 = (state.get_card_rects(Vector2(VIEW_SIZE))[0] as Rect2)

	# Prime all non-preview selection transitions, then freeze them in their
	# completed state so the visible/hidden pair differs only in the stat segment.
	renderer.set_training_stat_preview_draw_msec_for_tests(HIDDEN_DRAW_MSEC)
	state.set_status_hover_mouse_pos(Vector2(-1.0, -1.0))
	await _render(viewport, canvas)
	renderer.set("_choice_visual_transition_started_msec", -1000)

	var no_hover: Image = await _capture_case(
		viewport,
		canvas,
		state,
		renderer,
		Vector2(-1.0, -1.0),
		HIDDEN_DRAW_MSEC,
		output_dir.path_join("no_hover_2020x1246.png")
	)
	var hidden: Image = await _capture_case(
		viewport,
		canvas,
		state,
		renderer,
		card_rect.get_center(),
		HIDDEN_DRAW_MSEC,
		output_dir.path_join("hover_hidden_2020x1246.png")
	)
	var visible: Image = await _capture_case(
		viewport,
		canvas,
		state,
		renderer,
		card_rect.get_center(),
		VISIBLE_DRAW_MSEC,
		output_dir.path_join("hover_visible_2020x1246.png")
	)
	if no_hover == null or hidden == null or visible == null:
		quit(1)
		return
	var preview_model: Dictionary = renderer.get("_training_stat_preview_model")
	var segment_rect := _preview_segment_rect(state, preview_model)
	var visible_delta := _count_changed_pixels(hidden, visible, segment_rect)
	var hidden_delta := _count_changed_pixels(no_hover, hidden, segment_rect)
	if visible_delta < 30:
		push_error("visible preview did not paint enough changed segment pixels: %d" % visible_delta)
		quit(1)
		return
	if hidden_delta != 0:
		push_error("hidden hover must equal the no-hover baseline in the segment region: %d" % hidden_delta)
		quit(1)
		return

	viewport.remove_child(canvas)
	canvas.queue_free()
	var maximum_fixture: Dictionary = _build_fixture("physique_posture", true)
	var maximum_canvas := PreviewCanvas.new()
	maximum_canvas.renderer = maximum_fixture["renderer"]
	maximum_canvas.runtime_state = maximum_fixture["state"]
	maximum_canvas.catalog = RuntimePerkCatalog.new()
	maximum_canvas.icon_renderer = maximum_fixture["icon_renderer"]
	viewport.add_child(maximum_canvas)
	var maximum_state: Object = maximum_fixture["state"]
	var maximum_renderer: Object = maximum_fixture["renderer"]
	var maximum_rect: Rect2 = (maximum_state.get_card_rects(Vector2(VIEW_SIZE))[0] as Rect2)
	maximum_renderer.set_training_stat_preview_draw_msec_for_tests(VISIBLE_DRAW_MSEC)
	maximum_state.set_status_hover_mouse_pos(Vector2(-1.0, -1.0))
	await _render(viewport, maximum_canvas)
	maximum_renderer.set("_choice_visual_transition_started_msec", -1000)
	var maximum_baseline: Image = await _render(viewport, maximum_canvas)
	maximum_state.set_status_hover_mouse_pos(maximum_rect.get_center())
	var maximum_hover: Image = await _save_render(
		viewport,
		maximum_canvas,
		output_dir.path_join("maximum_no_preview_2020x1246.png")
	)
	if maximum_baseline == null or maximum_hover == null:
		quit(1)
		return
	var maximum_stats_rect: Rect2 = maximum_state.build_layout(Vector2(VIEW_SIZE)).get("stats_rect", Rect2())
	if _count_changed_pixels(maximum_baseline, maximum_hover, maximum_stats_rect) != 0:
		push_error("saturated card hover must not change the stats ledger")
		quit(1)
		return

	var strip := Image.create(VIEW_SIZE.x * 2, VIEW_SIZE.y, false, visible.get_format())
	strip.blit_rect(visible, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i.ZERO)
	strip.blit_rect(hidden, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i(VIEW_SIZE.x, 0))
	var strip_path := output_dir.path_join("blink_visible_hidden_frame_strip.png")
	if strip.save_png(strip_path) != OK:
		push_error("failed to save training preview frame strip: %s" % strip_path)
		quit(1)
		return

	PerkConversionFlags.debug_set_enabled(false)
	LanguageSettings.set_test_locale_override("")
	print("training_card_stat_preview_visual_qa: visible_changed_pixels=%d" % visible_delta)
	print("training_card_stat_preview_visual_qa: evidence=%s" % output_dir)
	print("training_card_stat_preview_visual_qa: captures=5")
	print("training_card_stat_preview_visual_qa: ok")
	quit(0)


func _build_fixture(training_id: String, saturated: bool) -> Dictionary:
	var state := RuntimePerkState.new()
	var owner := CaptureOwner.new()
	var mythic := CaptureMythicRuntime.new()
	var registry := CaptureRegistry.new()
	var renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	mythic.runtime_perk_state_ref = state
	registry.instances = {
		"runtime_perk_state": state,
		"mythic_item_runtime": mythic,
	}
	if not saturated:
		state.runtime_skill_levels["training_mastery"] = 5
		state.item_perk_level_bonus = 2
	var training_catalog := PhysiqueTrainingCatalog.new()
	var count := 0
	if saturated:
		while not state.is_physique_training_saturated(training_id, registry) and count < 30:
			if not state.apply_choice(training_catalog.build_card(training_id, count), owner, registry):
				break
			count += 1
	state.choice_active = true
	state.animation_time = 1.0
	state.pending_skill_choices = 1
	state.selected_index = 0
	var runtime_catalog := RuntimePerkCatalog.new()
	state.current_choices = [
		training_catalog.build_card(training_id, count, state.get_physique_training_multiplier()),
		runtime_catalog.get_perk_data("dash_jump"),
		runtime_catalog.get_perk_data("item_cooldown_mastery"),
	]
	state.capture_stats_context(owner, registry)
	renderer.prewarm_assets()
	icon_renderer.prewarm_assets()
	return {
		"state": state,
		"owner": owner,
		"registry": registry,
		"renderer": renderer,
		"icon_renderer": icon_renderer,
	}


func _capture_case(
	viewport: SubViewport,
	canvas: PreviewCanvas,
	state: Object,
	renderer: Object,
	mouse_pos: Vector2,
	draw_msec: int,
	output_path: String
) -> Image:
	state.set_status_hover_mouse_pos(mouse_pos)
	renderer.set_training_stat_preview_draw_msec_for_tests(draw_msec)
	return await _save_render(viewport, canvas, output_path)


func _save_render(viewport: SubViewport, canvas: PreviewCanvas, output_path: String) -> Image:
	var image: Image = await _render(viewport, canvas)
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		push_error("training preview capture returned an invalid image: %s" % output_path)
		return null
	if image.save_png(output_path) != OK:
		push_error("training preview capture save failed: %s" % output_path)
		return null
	print("[TrainingCardStatPreviewVisualQA] %s" % output_path)
	return image


func _render(viewport: SubViewport, canvas: PreviewCanvas) -> Image:
	canvas.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = viewport.get_texture()
	return texture.get_image() if texture != null else null


func _preview_segment_rect(state: Object, preview_model: Dictionary) -> Rect2:
	var stats_rect: Rect2 = state.build_layout(Vector2(VIEW_SIZE)).get("stats_rect", Rect2())
	var inner := stats_rect.grow(-11.0)
	var gauge_rect := CharacterInfoOverlayStatsPresenter.player_stat_gauge_rect(
		inner,
		CharacterInfoOverlayState.STAT_ROW_COUNT,
		int(preview_model.get("row_index", -1)),
		CharacterInfoOverlayState.UI_TEXT_SCALE
	)
	var left_x := gauge_rect.position.x + 5.0
	var right_x := gauge_rect.end.x - 5.0
	var current_x := lerpf(left_x, right_x, float(preview_model.get("current_fill_ratio", 0.0)))
	var projected_x := lerpf(left_x, right_x, float(preview_model.get("projected_fill_ratio", 0.0)))
	return Rect2(
		Vector2(current_x - 8.0, gauge_rect.get_center().y - 10.0),
		Vector2(maxf(1.0, projected_x - current_x + 16.0), 20.0)
	)


func _count_changed_pixels(first: Image, second: Image, region: Rect2) -> int:
	var count := 0
	var x0 := clampi(int(floor(region.position.x)), 0, VIEW_SIZE.x - 1)
	var x1 := clampi(int(ceil(region.end.x)), 0, VIEW_SIZE.x)
	var y0 := clampi(int(floor(region.position.y)), 0, VIEW_SIZE.y - 1)
	var y1 := clampi(int(ceil(region.end.y)), 0, VIEW_SIZE.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) >= PIXEL_DIFF_THRESHOLD:
				count += 1
	return count
