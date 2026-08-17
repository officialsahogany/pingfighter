extends SceneTree

# 퍽 선택 화면 하단 능력치 원장 + 축소된 카드의 "실제 픽셀" 판정.
# 데이터/호출 스모크(runtime_perk_choice_stats_band_smoke)는 행 개수와 값만
# 보증한다. 여기서는 실 Vulkan 렌더 결과를 떠서 아래를 본다:
#  [A] 원장 10행이 모두 실제로 잉크를 남긴다 (예약 높이가 맞아도 대비가
#      죽으면 화면에선 안 보인다 -- 한지 지면 위 먹색 대비 판정).
#  [B] 음성 대조: 최소 높이 미만 rect면 하위 행 밴드의 잉크가 0이다.
#  [C] 축소된 카드에서 최대 5줄 설명이 카드 밖으로 새지 않는다 (카드 높이를
#      390 -> 316으로 줄인 변경의 핵심 리스크).
# headless에서는 렌더링 서버가 dummy라 픽셀 캡처가 불가 -- 선례대로 스킵하고
# 비-headless 실행에서 전 레그를 판정한다.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")
const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(1000.0, 860.0)
const BAND_RECT := Rect2(30.0, 24.0, 913.0, 285.0)
const CARD_RECT := Rect2(60.0, 360.0, 353.0, 417.0)
const CAPTURE_DIR := "res://../.tmp/perk_stats_band_capture"
# 한지 지면(0.847/0.784/0.647 합 ≈ 2.28) 위의 먹색 라벨(합 ≈ 0.49) 판정 임계.
# 약한 임계는 종이 결/얼룩까지 잉크로 세므로 강하게 잡는다.
const INK_LUMA_THRESHOLD := 1.35

var _failures: Array[String] = []
var _viewport: SubViewport = null


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var player_paddle_width := 155.0
	var runtime_paddle_scale := 1.0
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null

	func get_cached_instance(_key: String) -> Object:
		return null


class FakeStatsContextState:
	extends RefCounted

	var owner: Object = FakeOwner.new()
	var registry: Object = FakeRegistry.new()

	func get_stats_context_owner() -> Object:
		return owner

	func get_stats_context_registry() -> Object:
		return registry

	func get_status_hover_mouse_pos() -> Vector2:
		return Vector2(-1.0, -1.0)


class CapturingProbe:
	extends Control

	var renderer: Object = null
	var runtime_state: Object = null
	var band_rect := Rect2()
	var draw_band := true
	var draw_card := false
	var card_choice: Dictionary = {}
	var row_rects: Array = []

	func _draw() -> void:
		# 흰 바탕: 한지 지면(밝음)과 먹색 텍스트(어두움)를 같은 임계로 가르고,
		# 카드 밖으로 샌 글자는 흰 배경 위 어두운 픽셀로 바로 잡힌다.
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 1.0, 1.0, 1.0))
		if draw_band:
			renderer._draw_stats_band(self, runtime_state, {}, band_rect)
			row_rects = renderer._stats_hover_row_rects.duplicate()
		if draw_card:
			renderer._draw_card(self, card_choice, CARD_RECT, true, 1.0, null, 1.0, 0)
			renderer._ensure_card_desc_cache([card_choice], CARD_RECT.size.x, null)
			var block := Rect2(
				Vector2(CARD_RECT.position.x, CARD_RECT.position.y + CARD_RECT.size.y * RuntimePerkChoiceLayout.CARD_DESCRIPTION_TOP_RATIO),
				Vector2(CARD_RECT.size.x, CARD_RECT.size.y * RuntimePerkChoiceLayout.CARD_DESCRIPTION_HEIGHT_RATIO)
			)
			renderer._draw_card_description_block(self, card_choice, renderer._card_desc_cache[0], block, true, 1.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("runtime_perk_choice_stats_band_render_capture_smoke: capture legs skipped under headless display server")
		print("runtime_perk_choice_stats_band_render_capture_smoke: ok")
		quit(0)
		return

	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	await _test_every_row_leaves_ink()
	await _test_under_minimum_band_clips_rows()
	await _test_shrunk_card_description_stays_inside()

	_viewport.queue_free()
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("runtime_perk_choice_stats_band_render_capture_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _make_probe() -> CapturingProbe:
	var probe := CapturingProbe.new()
	probe.size = VIEW_SIZE
	probe.renderer = RuntimePerkOverlayRenderer.new()
	probe.runtime_state = FakeStatsContextState.new()
	probe.band_rect = BAND_RECT
	_viewport.add_child(probe)
	return probe


func _capture(probe: CapturingProbe, slug: String) -> Image:
	probe.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = _viewport.get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	var output_path := ProjectSettings.globalize_path("%s/%s_%d_%d.png" % [CAPTURE_DIR, slug, OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if image.save_png(output_path) == OK:
		print("runtime_perk_choice_stats_band_render_capture_smoke: evidence %s" % output_path)
	return image


func _ink_count(image: Image, region: Rect2) -> int:
	var count := 0
	var x0: int = maxi(0, int(region.position.x))
	var y0: int = maxi(0, int(region.position.y))
	var x1: int = mini(image.get_width(), int(region.end.x))
	var y1: int = mini(image.get_height(), int(region.end.y))
	for y in range(y0, y1):
		for x in range(x0, x1):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < INK_LUMA_THRESHOLD:
				count += 1
	return count


# [A] 예약된 원장 안에서 10행이 전부 실제 잉크를 남기는가. 라벨 칼럼만 본다
#     (게이지 바/수치는 색이 달라 임계가 다르다).
func _test_every_row_leaves_ink() -> void:
	var probe := _make_probe()
	var image: Image = await _capture(probe, "band_full")
	if image == null:
		_expect(false, "band capture must produce an image")
		probe.queue_free()
		return
	var rows: Array = probe.row_rects
	_expect(rows.size() == CharacterInfoOverlayState.STAT_ROW_COUNT, "capture probe must draw all 10 rows, drew %d" % rows.size())
	for index in range(rows.size()):
		var row: Rect2 = rows[index]
		var label_region := Rect2(row.position, Vector2(minf(200.0, row.size.x), row.size.y))
		var ink: int = _ink_count(image, label_region)
		_expect(ink >= 30, "row %d must render readable ink on the hanji ledger (ink=%d)" % [index, ink])
	# 원장 바깥으로 새지 않는가: 띠 아래 24px 밴드는 흰 배경 그대로여야 한다.
	var below := Rect2(Vector2(BAND_RECT.position.x, BAND_RECT.end.y + 4.0), Vector2(BAND_RECT.size.x, 20.0))
	_expect(_ink_count(image, below) == 0, "stats band must not bleed ink below its own rect")
	probe.queue_free()


# [B] 음성 대조 -- 최소 높이 미만이면 하위 행이 실제로 사라진다.
func _test_under_minimum_band_clips_rows() -> void:
	var probe := _make_probe()
	probe.band_rect = Rect2(BAND_RECT.position, Vector2(BAND_RECT.size.x, RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT - 60.0))
	var image: Image = await _capture(probe, "band_under_minimum")
	if image == null:
		_expect(false, "under-minimum band capture must produce an image")
		probe.queue_free()
		return
	_expect(
		probe.row_rects.size() < CharacterInfoOverlayState.STAT_ROW_COUNT,
		"an under-minimum band must clip rows -- otherwise leg [A] proves nothing"
	)
	var tail := Rect2(
		Vector2(BAND_RECT.position.x, BAND_RECT.position.y + RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT - 56.0),
		Vector2(200.0, 40.0)
	)
	_expect(_ink_count(image, tail) == 0, "clipped rows must leave no ink past the shortened band")
	probe.queue_free()


# [C] 카드 높이를 줄인 뒤에도 최대 5줄 설명이 카드 안에 머무는가.
func _test_shrunk_card_description_stays_inside() -> void:
	var probe := _make_probe()
	probe.draw_band = false
	probe.draw_card = true
	probe.card_choice = {
		"name": "유운보 수련",
		"id": "physique_move_speed",
		"description": "이동 속도 +25%, 활주 거리 +40%, 활주 후딜 -50%, 최대 기력 +120",
		"detail": "무공을 익히면 몸이 가벼워져 발놀림이 빨라지고, 활주 거리가 늘어나며, 후딜이 줄어 연속 대응이 한결 쉬워집니다.",
		"current_level": 3,
		"next_level": 4,
		"max_level": 5,
		"icon_color": Color(0.6, 0.8, 1.0),
	}
	var image: Image = await _capture(probe, "card_description")
	if image == null:
		_expect(false, "card capture must produce an image")
		probe.queue_free()
		return
	var desc_top: float = CARD_RECT.position.y + CARD_RECT.size.y * RuntimePerkChoiceLayout.CARD_DESCRIPTION_TOP_RATIO
	var desc_region := Rect2(Vector2(CARD_RECT.position.x, desc_top), Vector2(CARD_RECT.size.x, CARD_RECT.end.y - desc_top))
	_expect(_ink_count(image, desc_region) >= 200, "the 5-line description must actually render inside the card")
	# 카드 아래 24px: 설명이 카드 밖으로 새면 흰 배경 위 어두운 글자로 잡힌다.
	var below_card := Rect2(Vector2(CARD_RECT.position.x, CARD_RECT.end.y + 3.0), Vector2(CARD_RECT.size.x, 24.0))
	var spill: int = _ink_count(image, below_card)
	_expect(spill == 0, "shrunk card must not spill description text below its own rect (spill=%d)" % spill)
	probe.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
