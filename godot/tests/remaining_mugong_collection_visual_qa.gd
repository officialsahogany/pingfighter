extends SceneTree

const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")

const VIEW_SIZE := Vector2i(1180, 920)
const CAPTURE_PATH := "res://.tmp/remaining_mugong_collection_qa.png"
const CELL_FILL := Color(20.0 / 255.0, 25.0 / 255.0, 38.0 / 255.0, 0.96)
const SPECS := [
	["star_detector", "낙성결"], ["adversity_armor", "역천호신"], ["reinforced_boomerang_gauntlet", "회선철수"],
	["sensor", "감응보"], ["dowsing_pendulum", "섭물공"],
	["dowsing_goggles", "천안결"], ["chargebag", "반탄심법"], ["battery", "장기심법"],
	["master", "축성공"], ["gold_digger", "취금결"],
	["lucky_coin", "쌍복결"], ["shrapnel_armor", "산화수"], ["fuel_pouch", "태허심법"],
	["bluetooth_ring", "격기심법"], ["foul_whistle", "반전결"],
	["neural_helmet", "강신결"], ["commando_arm", "비병결"], ["rainbow_fur_glove", "칠채순환"],
	["knee_pads", "비각축기"], ["soul_burst", "폭혼보"], ["bulletproof_hat", "철심공"],
	["venom_mist_gauntlet", "독운공"], ["sage_ring", "현문차력"],
	["dash_spirit", "잔영호법"], ["extension_gear", "불식심법"],
	["combo_amplifier_chip", "축뢰심법"], ["jetpack_enhance", "승운신법"], ["kick_enhance", "천각심법"],
	["blade_amp", "검강심법"], ["four_poisons", "사독귀일"], ["pistol_enhance", "철포결"],
]
const ACCENTS := [
	Color(0.72, 0.49, 0.17), Color(0.65, 0.25, 0.20), Color(0.26, 0.52, 0.50),
	Color(0.30, 0.55, 0.35), Color(0.33, 0.42, 0.67), Color(0.48, 0.30, 0.62),
]


class CollectionProbe:
	extends Node2D

	var renderer: Object = null
	var draw_results: Array[bool] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.026, 0.020, 0.015), true)
		draw_results.clear()
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(28.0, 38.0), "남은 일반 무공 31종 · 원형 한지 탁본 인장", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.95, 0.84, 0.61))
		for index in SPECS.size():
			var spec: Array = SPECS[index]
			var column := index % 6
			var row := index / 6
			var left := 28.0 + float(column) * 190.0
			var top := 70.0 + float(row) * 140.0
			var acquisition_slot := Rect2(Vector2(left, top + 20.0), Vector2(82.0, 82.0))
			var owned_slot := Rect2(Vector2(left + 125.0, top + 47.0), Vector2(32.0, 32.0))
			var accent: Color = ACCENTS[index % ACCENTS.size()]
			CharacterInfoOverlayTextureDrawer.draw_mugong_seal_cell(self, acquisition_slot, CELL_FILL, Color(accent.r, accent.g, accent.b, 0.90), 2.0)
			CharacterInfoOverlayTextureDrawer.draw_mugong_seal_cell(self, owned_slot, CELL_FILL, Color(accent.r, accent.g, accent.b, 0.78), 1.1)
			draw_results.append(renderer.draw_icon(self, str(spec[0]), acquisition_slot.grow(-5.0), 1.0, true))
			draw_results.append(renderer.draw_icon(self, str(spec[0]), owned_slot.grow(-1.5), 1.0, true))
			if font != null:
				draw_string(font, Vector2(left, top + 4.0), str(spec[1]), HORIZONTAL_ALIGNMENT_LEFT, 116.0, 17, Color(0.94, 0.84, 0.63))
				draw_string(font, Vector2(left + 119.0, top + 98.0), "32px", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.72, 0.66, 0.56))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var renderer := RuntimePerkIconRenderer.new()
	for spec: Array in SPECS:
		var perk_id := str(spec[0])
		if not renderer.has_icon(perk_id) or renderer.has_animated_icon(perk_id):
			push_error("Remaining Mugong should resolve as a static seal before visual QA: %s" % perk_id)
			quit(1)
			return
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("remaining_mugong_collection_visual_qa: capture skipped under headless display server")
		print("remaining_mugong_collection_visual_qa: ok")
		quit(0)
		return
	var probe := CollectionProbe.new()
	probe.renderer = renderer
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
	if probe.draw_results.size() != SPECS.size() * 2 or probe.draw_results.has(false):
		push_error("All 33 remaining Mugong should draw through round acquisition and 32px owned slots")
		quit(1)
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(CAPTURE_PATH) != OK:
		push_error("Failed to save the remaining Mugong collection visual QA capture")
		quit(1)
		return
	probe.queue_free()
	viewport.queue_free()
	await process_frame
	print("remaining_mugong_collection_visual_qa: ok")
	print(ProjectSettings.globalize_path(CAPTURE_PATH))
	quit(0)
