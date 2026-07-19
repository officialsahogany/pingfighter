extends SceneTree

const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

const VIEW_SIZE := Vector2(360.0, 430.0)
const CONTENT_RECT := Rect2(Vector2(24.0, 22.0), Vector2(300.0, 360.0))
const OUT_DIR := "res://../tmp"
const OUT_PATH := "res://../tmp/lingpet_ring_core_row_probe.png"
const STAT_BUFF_COLOR := Color(0.45, 1.0, 0.68, 1.0)
const EMPTY_TEXT_COLOR := Color(0.70, 0.76, 0.84, 0.82)
const ACCENT_BLUE := Color(0.28, 0.82, 1.0, 1.0)
const SLOT_FILL := Color(0.05, 0.08, 0.13, 0.90)

var _failures: Array[String] = []


class RingCoreProbe:
	extends Control

	var font: Font
	var hover_data: Dictionary = {}
	var ring_core_rects: Array = []
	var skill_icon_rects: Array = []
	var skill_icon_texture_cache: Dictionary = {}
	var art_texture_cache: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.012, 0.016, 0.026, 1.0))
		hover_data = {}
		ring_core_rects.clear()
		skill_icon_rects.clear()
		CharacterInfoOverlayLingpetPresenter.draw_companion_panel(
			self,
			font,
			CONTENT_RECT,
			_build_snapshot(),
			_ring_core_label_hover_pos(),
			hover_data,
			skill_icon_rects,
			[],
			[],
			ring_core_rects,
			art_texture_cache,
			skill_icon_texture_cache,
			STAT_BUFF_COLOR,
			EMPTY_TEXT_COLOR,
			ACCENT_BLUE,
			SLOT_FILL,
			24,
			1.0,
			0.0
		)

	func _build_snapshot() -> Dictionary:
		return {
			"state": "companion",
			"pet_id": "maribo",
			"title": "마리보",
			"subtitle": "동행 중",
			"affinity_level": 7,
			"affinity_points": 25.0,
			"affinity_next_requirement": 50.0,
			"affinity_next_label": "2번째 패시브 스킬 +1",
			"satiety_pct": 73,
			"companion_exhausted": false,
			"satiety_exhaustion_ratio": 0.0,
			"ring_core_tier": 3,
			"affinity_chip_count": 4,
			"companion_skill_id": "maribo_hydro_sphere",
			"companion_skill_name": "하이드로 스피어",
			"companion_skill_card_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v1.png",
			"companion_skill_icon_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skill_icon_imagegen_v1.png",
			"companion_skill_cooldown_duration": 40.0,
			"companion_skill_level": 2,
			"companion_passive_skill_id": "lingpet_resonance_boost",
			"companion_passive_skill_name": "공명 부스트",
			"companion_passive_skill_level": 2,
		}

	func _ring_core_label_hover_pos() -> Vector2:
		var art_rect: Rect2 = CharacterInfoOverlayLingpetPresenter.companion_art_rect(
			CONTENT_RECT,
			clamp(CONTENT_RECT.size.y * 0.22, 58.0, 78.0) + CharacterInfoOverlayLingpetPresenter.RING_CORE_ROW_HEIGHT,
			CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT
		)
		var affinity_rect := Rect2(
			art_rect.position.x,
			art_rect.end.y + 4.0,
			art_rect.size.x,
			max(24.0, CharacterInfoOverlayLingpetPresenter.AFFINITY_BAND_HEIGHT - 10.0)
		)
		var row_rect := Rect2(
			affinity_rect.position.x,
			affinity_rect.end.y + 4.0,
			affinity_rect.size.x,
			CharacterInfoOverlayLingpetPresenter.RING_CORE_ROW_HEIGHT
		)
		return row_rect.position + Vector2(row_rect.size.x - 18.0, row_rect.size.y * 0.50)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_ring_core_art_family()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := RingCoreProbe.new()
	probe.size = VIEW_SIZE
	probe.font = ThemeDB.fallback_font
	viewport.add_child(probe)
	probe.queue_redraw()

	for _idx in range(6):
		await process_frame

	_expect(probe.ring_core_rects.size() == 1, "T3 lingpet panel should publish one ring-core hover rect")
	if probe.ring_core_rects.size() == 1:
		var ring_rect: Rect2 = probe.ring_core_rects[0]
		_expect(ring_rect.size.x >= 54.0 and ring_rect.size.y >= 54.0, "ring-core slot should render at the enlarged row size")
	_expect(str(probe.hover_data.get("title", "")) == "링코어", "hovering the row label area should resolve the ring-core tooltip")
	_expect(str(probe.hover_data.get("subtitle", "")) == "T3", "ring-core tooltip should expose the run tier")
	_expect(str(probe.hover_data.get("body", "")).find("Lv.15") >= 0, "ring-core tooltip should expose the T3 affinity cap")  # 현행 룰 T3=15(백업 계약 30은 룰 트랙 소유)

	var display_name := DisplayServer.get_name().to_lower()
	if display_name.find("headless") >= 0:
		viewport.queue_free()
		_finish("character_info_lingpet_ring_core_visual_smoke: ok (viewport pixel capture skipped under headless display server)")
		return

	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		viewport.queue_free()
		_finish("character_info_lingpet_ring_core_visual_smoke: ok (viewport pixel capture skipped under dummy renderer)")
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		viewport.queue_free()
		_finish("character_info_lingpet_ring_core_visual_smoke: ok (viewport pixel capture skipped under dummy renderer)")
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var save_error := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	_expect(save_error == OK, "lingpet ring-core visual probe should save a runtime screenshot")
	_verify_ring_core_pixels(image, probe)

	viewport.queue_free()
	_finish("character_info_lingpet_ring_core_visual_smoke: ok\nruntime_probe=%s" % ProjectSettings.globalize_path(OUT_PATH))


func _verify_ring_core_art_family() -> void:
	for tier in range(1, LingpetRingCoreRules.MAX_RING_CORE_TIER + 1):
		var texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_ring_core_icon_texture(tier, {})
		_expect(texture != null, "ring-core visual probe should resolve tier %d art" % tier)


func _verify_ring_core_pixels(image: Image, probe: RingCoreProbe) -> void:
	if probe.ring_core_rects.is_empty():
		return
	var ring_rect: Rect2 = probe.ring_core_rects[0]
	_expect(_max_visible_energy(image, ring_rect.grow(-4.0)) > 0.22, "ring-core slot should render nonblank tier-art pixels")
	var label_rect := Rect2(Vector2(ring_rect.end.x + 30.0, ring_rect.position.y + 6.0), Vector2(120.0, 48.0))
	_expect(_max_visible_energy(image, label_rect) > 0.18, "ring-core row labels should render visible text pixels")


func _max_visible_energy(image: Image, rect: Rect2) -> float:
	var max_energy := 0.0
	var min_x := clampi(floori(rect.position.x), 0, image.get_width() - 1)
	var min_y := clampi(floori(rect.position.y), 0, image.get_height() - 1)
	var max_x := clampi(ceili(rect.end.x), 0, image.get_width() - 1)
	var max_y := clampi(ceili(rect.end.y), 0, image.get_height() - 1)
	var step_x := maxi(1, int((max_x - min_x) / 10))
	var step_y := maxi(1, int((max_y - min_y) / 10))
	for y in range(min_y, max_y + 1, step_y):
		for x in range(min_x, max_x + 1, step_x):
			max_energy = maxf(max_energy, _visible_energy(image.get_pixel(x, y)))
	return max_energy


func _visible_energy(color: Color) -> float:
	return maxf(color.a, 0.0) * (color.r + color.g + color.b)


func _finish(ok_message: String) -> void:
	if _failures.is_empty():
		print(ok_message)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
