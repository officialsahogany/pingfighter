extends SceneTree

# Throwaway visual-QA harness for the character info overlay editorial chrome pass.
# Renders CharacterInfoOverlay.draw() onto a SubViewport at the real project view
# size with a null owner/registry (empty account state) so the frame, section
# chrome, and empty states can be eyeballed. Run WITHOUT --headless.
#
#   godot --path godot -s res://tools/character_info_overlay_capture.gd

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayTextureDrawer := preload("res://scripts/hud/character_info_overlay_texture_drawer.gd")
const OUT_DIR := "d:/tmp/bosspong_ui_panel_capture/char_info_editorial"
const VIEW := Vector2(2020, 1246)


class OverlayDrawer:
	extends Node2D

	var overlay: Object
	var view: Vector2

	func _draw() -> void:
		# Fake battle backdrop so the glass panels have something to read over.
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.13, 0.22, 0.34))
		draw_rect(Rect2(0.0, view.y * 0.55, view.x, view.y * 0.45), Color(0.09, 0.15, 0.24))
		draw_circle(Vector2(view.x * 0.30, view.y * 0.42), 130.0, Color(0.85, 0.55, 0.25, 0.55))
		draw_circle(Vector2(view.x * 0.72, view.y * 0.30), 90.0, Color(0.30, 0.75, 0.95, 0.5))
		draw_rect(Rect2(view.x * 0.42, view.y * 0.86, 240.0, 26.0), Color(0.2, 0.9, 0.6, 0.6))
		overlay.draw(self, null, null, view)


class ComponentDrawer:
	extends Node2D

	var aurora: Texture2D
	var hologram: Texture2D

	func _draw_hologram_with_highlight(rect: Rect2, slot_key: String) -> void:
		if hologram == null:
			return
		var texture_size: Vector2 = hologram.get_size()
		var fit_scale: float = min(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
		var dest := Rect2(rect.get_center() - texture_size * fit_scale * 0.5, texture_size * fit_scale)
		draw_texture_rect(hologram, dest, false, Color(1.0, 1.0, 1.0, 0.92))
		var region_value: Variant = CharacterInfoOverlay.EQUIPMENT_HOLOGRAM_REGIONS.get(slot_key)
		if region_value is Rect2:
			var region: Rect2 = region_value
			var src := Rect2(region.position * texture_size, region.size * texture_size)
			var dst := Rect2(dest.position + region.position * dest.size, region.size * dest.size)
			draw_texture_rect_region(hologram, dst, src, Color(1.0, 1.0, 1.0, 0.9))
			draw_texture_rect_region(hologram, dst, src, Color(0.72, 0.95, 1.0, 0.55))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4.0, -6.0), slot_key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.7, 0.9, 1.0))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(2020, 1246)), Color(0.07, 0.09, 0.14))
		var highlight_keys := ["head", "top", "left_arm", "belt", "knee", "shoes"]
		for k in range(highlight_keys.size()):
			_draw_hologram_with_highlight(Rect2(1180.0 + float(k % 3) * 280.0, 60.0 + float(k / 3) * 580.0, 250.0, 540.0), highlight_keys[k])
		var rim_colors := [
			Color(0.95, 0.35, 0.35, 0.85),
			Color(1.0, 0.75, 0.25, 0.85),
			Color(0.62, 0.45, 1.0, 0.85),
			Color(0.95, 0.45, 0.85, 0.85),
			Color(0.35, 0.85, 0.80, 0.85),
			Color(0.40, 0.95, 0.55, 0.85),
		]
		var font := ThemeDB.fallback_font
		for i in range(rim_colors.size()):
			var cell := Rect2(120.0 + float(i) * 130.0, 90.0, 104.0, 104.0)
			CharacterInfoOverlayTextureDrawer.draw_hex_cell(self, cell, Color(0.08, 0.10, 0.16, 0.96), rim_colors[i], 1.2)
			var badge := Rect2(cell.get_center().x - 16.0, cell.end.y - 22.0, 32.0, 13.0)
			draw_rect(badge, Color(0.05, 0.09, 0.15, 0.92))
			draw_rect(badge, Color(rim_colors[i].r, rim_colors[i].g, rim_colors[i].b, 0.55), false, 1.0)
			draw_string(font, badge.position + Vector2(5.0, 10.5), "Lv %d" % ((i % 3) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(1.0, 0.85, 0.4))
		if aurora != null:
			CharacterInfoOverlayLingpetPresenter._draw_aurora_backdrop(self, Rect2(120.0, 260.0, 560.0, 430.0), aurora, 6.0)
			CharacterInfoOverlayLingpetPresenter._draw_aurora_backdrop(self, Rect2(760.0, 260.0, 380.0, 560.0), aurora, 19.0)
			draw_rect(Rect2(760.0, 260.0, 380.0, 560.0), Color(0.3, 0.8, 1.0, 0.5), false, 1.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("character_info_overlay_capture must run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEW)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	print("[CharInfoCapture] instantiating overlay")
	var overlay: Object = CharacterInfoOverlay.new()
	print("[CharInfoCapture] overlay ready, activating")
	overlay.active = true
	overlay._ensure_editorial_bg_texture()
	overlay._ensure_empty_hero_textures()
	overlay._ensure_scene_dressing_textures()
	overlay.animation_time = 10.0
	var drawer := OverlayDrawer.new()
	drawer.overlay = overlay
	drawer.view = VIEW
	viewport.add_child(drawer)
	drawer.queue_redraw()
	await process_frame
	await process_frame
	var img: Image = viewport.get_texture().get_image()
	img.save_png("%s/char_info_main.png" % OUT_DIR)
	print("[CharInfoCapture] char_info_main saved")
	viewport.remove_child(drawer)
	drawer.queue_free()

	var comp := ComponentDrawer.new()
	comp.aurora = CharacterInfoOverlayLingpetTextureLoader.get_panel_aurora_texture({})
	comp.hologram = overlay._human_hologram_texture
	viewport.add_child(comp)
	comp.queue_redraw()
	await process_frame
	await process_frame
	var comp_img: Image = viewport.get_texture().get_image()
	comp_img.save_png("%s/char_info_components.png" % OUT_DIR)
	print("[CharInfoCapture] char_info_components saved")
	quit(0)
