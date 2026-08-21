extends SceneTree

# Windowed Vulkan evidence for the standard runtime Mugong-choice route.
# Usage:
#   Godot..._console.exe --path . --rendering-method mobile \
#     -s res://tools/runtime_perk_traditional_choice_capture.gd

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const MysticDiceOfferPlanner := preload("res://scripts/characters/mystic_dice_offer_planner.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const OUT_DIR := "D:/tmp/bosspong_ui_panel_capture/runtime_perk_traditional"


class CaptureCanvas:
	extends Node2D

	var renderer: Object
	var state: Object
	var catalog: Object
	var icon_renderer: Object
	var view_size := Vector2.ZERO

	func _draw() -> void:
		# Synthetic playfield behind the modal: the production renderer is composed
		# after the live battle scene. Keeping this fixture visible catches accidental
		# opaque-fullscreen regressions in the traditional backdrop.
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.16, 0.095, 0.065))
		draw_rect(Rect2(view_size * Vector2(0.16, 0.08), view_size * Vector2(0.68, 0.82)), Color(0.075, 0.18, 0.16))
		draw_circle(view_size * Vector2(0.50, 0.52), minf(view_size.x, view_size.y) * 0.16, Color(0.26, 0.12, 0.08, 0.82))
		for lane: int in range(5):
			var y: float = view_size.y * (0.20 + float(lane) * 0.14)
			draw_line(Vector2(view_size.x * 0.12, y), Vector2(view_size.x * 0.88, y), Color(0.72, 0.52, 0.24, 0.22), 2.0)
		renderer.draw(self, state, catalog, view_size, icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("runtime_perk_traditional_choice_capture requires a windowed renderer")
		quit(1)
		return
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if mkdir_error != OK:
		push_error("failed to create runtime perk capture directory: %d" % mkdir_error)
		quit(1)
		return
	var ok := true
	ok = await _capture(Vector2i(1280, 720), _base_choices(), 1, "perk_choice_3_cards_1280x720.png") and ok
	ok = await _capture(Vector2i(1280, 720), _choices_with_dice(), 3, "perk_choice_4_cards_dice_1280x720.png") and ok
	ok = await _capture(Vector2i(1280, 720), _choices_with_training(), 2, "perk_choice_3_cards_training_1280x720.png") and ok
	ok = await _capture(Vector2i(1280, 720), _choices_with_dowsing_and_dice(), 4, "perk_choice_5_cards_dowsing_dice_1280x720.png") and ok
	ok = await _capture(Vector2i(760, 750), _choices_with_training(), 2, "perk_choice_3_cards_training_compact_760x750.png") and ok
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	if not ok:
		quit(1)
		return
	print("runtime_perk_traditional_choice_capture: ok")
	print("runtime_perk_traditional_choice_capture: evidence=", OUT_DIR)
	quit(0)


func _capture(size: Vector2i, choices: Array, selected_index: int, output_name: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var state := RuntimePerkState.new()
	state.choice_active = true
	state.animation_time = 1.0
	state.pending_skill_choices = 1
	state.gold_from_perks = 127
	state.runtime_skill_levels = {
		"dash_acceleration": 2,
		"item_luck": 1,
	}
	state.current_perk_slot_status = {"count": 2, "limit": 6, "is_full": false}
	state.current_choices = choices.duplicate(true)
	state.selected_index = selected_index

	var catalog := RuntimePerkCatalog.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	# This capture loads only the six visible icons. Production prewarm still owns
	# the full icon set before battle; the capture does not need to pay that cost.
	for icon_id: String in ["common_refresh", "dash_acceleration", "item_luck", "item_gauge_mastery", "mystic_dice", "physique_chosik_cooldown"]:
		icon_renderer._get_icon_source(icon_id)
	var renderer := RuntimePerkOverlayRenderer.new()
	renderer.prewarm_traditional_choice_assets()
	var canvas := CaptureCanvas.new()
	canvas.renderer = renderer
	canvas.state = state
	canvas.catalog = catalog
	canvas.icon_renderer = icon_renderer
	canvas.view_size = Vector2(size)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var output_path := OUT_DIR.path_join(output_name)
	var saved := image != null and not image.is_empty() and image.save_png(output_path) == OK
	if not saved:
		push_error("failed to save runtime perk capture: %s" % output_path)
	else:
		print("runtime_perk_traditional_choice_capture: ", output_path)
	viewport.queue_free()
	await process_frame
	return saved


func _base_choices() -> Array:
	var choices: Array = [
		{
			"id": "common_refresh",
			"name": "비급 재개봉",
			"description": "선택지를 즉시 새로 엽니다.",
			"detail": "흐트러진 기운을 거두고 새로운 무공 네 장을 다시 펼칩니다.",
			"current_level": 0,
			"next_level": 0,
			"max_level": 1,
			"tree": "instant",
			"is_instant": true,
			"icon_color": Color(0.38, 0.55, 0.50),
		},
		{
			"id": "dash_acceleration",
			"name": "대붕전익",
			"description": "활주시 패들 세로 210%·가로 30% 증가",
			"detail": "대붕이 날개를 펼치듯 활주 중 받아내는 범위를 넓힙니다.",
			"current_level": 2,
			"next_level": 3,
			"max_level": 5,
			"tree": "dash",
			"icon_color": Color(0.52, 0.76, 0.90),
		},
		{
			"id": "item_luck",
			"name": "천운감식",
			"description": "아이템 등장 확률 +10%",
			"detail": "길한 기운을 읽어 전장에 숨은 보물을 더 자주 발견합니다.",
			"current_level": 2,
			"next_level": 3,
			"max_level": 5,
			"tree": "item",
			"icon_color": Color(0.86, 0.64, 0.32),
		},
	]
	return choices


func _choices_with_dice() -> Array:
	var choices := _base_choices()
	choices.append(MysticDiceOfferPlanner.build_card())
	return choices


func _choices_with_training() -> Array:
	var choices := _base_choices()
	choices[2] = PhysiqueTrainingCatalog.new().build_card("physique_chosik_cooldown", 0)
	return choices


func _choices_with_dowsing_and_dice() -> Array:
	var choices := _base_choices()
	var dowsing_bonus := RuntimePerkCatalog.new().get_perk_data("item_gauge_mastery")
	dowsing_bonus["is_dowsing_goggles_bonus"] = true
	dowsing_bonus["bonus_source_item"] = "dowsing_goggles"
	dowsing_bonus["offer_lane"] = "dowsing_bonus"
	dowsing_bonus["offer_protected"] = true
	choices.append(dowsing_bonus)
	choices.append(MysticDiceOfferPlanner.build_card())
	return choices
