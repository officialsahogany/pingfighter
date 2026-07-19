extends SceneTree

# 코덱스 v2 P2 게이트 씰: 상태 패널 그리드·hover 우측 패널의 "실제 CanvasItem
# 렌더 경로" 픽셀 판정. 데이터 조립 스모크(perk_status_owned_tooltip_smoke)와
# 달리 실 Control _draw()에서 _draw_status_panel을 호출하고, 캡처는
# RenderingServer.frame_post_draw 이후 root 뷰포트에서 뜬다.
#  - [A] 5소모+비소모(common_expansion Lv.1): 실렌더된 빈칸 정확 2개(십자
#    글리프+어두운 셀 배경)와 후미 비소모 셀
#  - [B] 주사위 셀 hover: 우측 능력치 패널 실렌더 — benefit(녹)/curse(적)
#    색 픽셀 판정(주사위 고유색, 패널의 골드/청색과 판별식 분리)
#  - [C] 음성 대조: 같은 fixture에서 hover만 끄면 benefit/curse 색 0픽셀
# headless에서는 렌더링 서버가 dummy라 픽셀 캡처가 불가 — perk_slot_limit
# 선례대로 스킵하고, 비-headless 게이트 실행에서 전 레그를 판정한다.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(960.0, 720.0)
const PANEL_RECT := Rect2(40.0, 420.0, 880.0, 170.0)
const CAPTURE_DIR := "res://../.tmp/perk_status_panel_capture"

var _failures: Array[String] = []
var _viewport: SubViewport = null


class StatusPanelProbe:
	extends Control

	var renderer: Object = null
	var runtime_state: Object = null
	var snapshot: Dictionary = {}
	var catalog: Object = null
	var icon_renderer: Object = null
	var panel_rect := Rect2()
	var view_size := Vector2.ZERO

	func _draw() -> void:
		# 실 CanvasItem 렌더 경로: hover 판정→툴팁 호출까지 _draw_status_panel
		# 내부의 실코드가 이 Control 위에 그대로 실행된다.
		renderer._draw_status_panel(self, runtime_state, snapshot, catalog, panel_rect, icon_renderer, view_size)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("perk_status_panel_render_capture_smoke: capture legs skipped under headless display server")
		print("perk_status_panel_render_capture_smoke: ok")
		quit(0)
		return

	# SubViewport 격리(z_order 스모크 선례): 캡처가 창 크기/하이DPI 스케일과
	# 무관하게 정확히 VIEW_SIZE 1:1 좌표계로 뜨고, 외부 렌더 요소가 픽셀
	# 판정을 오염시키지 못한다.
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	PerkConversionFlags.debug_set_enabled(true)
	await _test_grid_renders_two_empty_and_trailing_free_cell()
	await _test_dice_hover_renders_right_panel_colors()
	PerkConversionFlags.debug_set_enabled(false)
	_viewport.queue_free()

	if _failures.is_empty():
		print("perk_status_panel_render_capture_smoke: ok")
		ProjectResourceLoader.clear_caches()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	ProjectResourceLoader.clear_caches()
	quit(1)


# 렌더러 _draw_status_panel의 그리드 기하 재현(display_slots는 조립 결과 수).
func _cell_rect(index: int, display_slots: int) -> Rect2:
	var icons_left: float = PANEL_RECT.position.x + 18.0
	var counter_col_left: float = PANEL_RECT.end.x - 130.0
	var gap := 10.0
	var avail_w: float = max(60.0, counter_col_left - icons_left - 6.0)
	var fit_size: float = (avail_w - gap * float(max(0, display_slots - 1))) / float(display_slots)
	var icon_size: float = clamp(fit_size, 28.0, 54.0)
	var row_y: float = PANEL_RECT.position.y + 52.0
	return Rect2(Vector2(icons_left + float(index) * (icon_size + gap), row_y), Vector2(icon_size, icon_size))


func _capture(probe: StatusPanelProbe, slug: String) -> Image:
	probe.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var viewport_texture := _viewport.get_texture()
	if viewport_texture == null:
		return null
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return null
	var output_path := ProjectSettings.globalize_path("%s/%s_%d_%d.png" % [CAPTURE_DIR, slug, OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if image.save_png(output_path) == OK:
		print("perk_status_panel_render_capture_smoke: evidence %s" % output_path)
	return image


func _cell_probe_luma(image: Image, cell: Rect2) -> float:
	# 셀 배경 샘플: 테두리(1.4px)와 중심 글리프를 피한 좌상 인셋.
	var p := image.get_pixel(int(cell.position.x + 5.0), int(cell.position.y + 5.0))
	return p.r + p.g + p.b


func _cell_center_luma(image: Image, cell: Rect2) -> float:
	var c := cell.get_center()
	var p := image.get_pixel(int(c.x), int(c.y))
	return p.r + p.g + p.b


func _count_color(image: Image, region: Rect2, classifier: Callable) -> int:
	var count := 0
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if classifier.call(image.get_pixel(x, y)):
				count += 1
	return count


func _is_dice_benefit_green(p: Color) -> bool:
	# benefit (0.45, 0.95, 0.55): 녹 우세. 슬롯 카운터 청색(0.67,0.88,1.0)은
	# g>b+0.2에서 탈락, 골드(1.0,0.84,·)는 g>r+0.2에서 탈락.
	return p.g > 0.55 and p.g > p.r + 0.2 and p.g > p.b + 0.2


func _is_dice_curse_red(p: Color) -> bool:
	# curse (1.0, 0.45, 0.42): 적 우세. 골드(1.0,0.84,·)는 r>g+0.3에서 탈락.
	return p.r > 0.55 and p.r > p.g + 0.3 and p.r > p.b + 0.3


func _test_grid_renders_two_empty_and_trailing_free_cell() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	var levels := {
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"item_luck": 1,
		"common_swiftness": 1,
		"common_expansion": 1,
	}
	# 라이브 정합: state와 snapshot은 같은 레벨을 본다(불일치 시 배지 레벨이
	# effective 0으로 그려지는 fixture 한정 왜곡).
	state.runtime_skill_levels = levels.duplicate(true)
	var probe := StatusPanelProbe.new()
	probe.size = VIEW_SIZE
	probe.renderer = renderer
	probe.runtime_state = state
	probe.snapshot = {"runtime_skill_levels": levels}
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	probe.panel_rect = PANEL_RECT
	probe.view_size = VIEW_SIZE
	_viewport.add_child(probe)
	var image: Image = await _capture(probe, "grid_5_of_7_plus_free")
	probe.queue_free()
	if image == null:
		_failures.append("grid capture must produce a non-empty image")
		return

	# 조립 결과(소모 5 + empty 2 + free 1 = 8셀)의 실렌더 판별: empty 셀은
	# 어두운 셀 배경 + 중심 십자 글리프(배경보다 밝음), 소모/free 셀은 색
	# 배경(밝음). 임계는 실측 캘리브(배경≈0.19 luma, 소모 셀≥0.55).
	var display_slots := 8
	var empty_indices: Array = []
	for idx in range(display_slots):
		var cell := _cell_rect(idx, display_slots)
		var bg_luma := _cell_probe_luma(image, cell)
		var center_luma := _cell_center_luma(image, cell)
		var reads_empty: bool = bg_luma < 0.42 and center_luma > bg_luma + 0.12
		if reads_empty:
			empty_indices.append(idx)
	_expect(
		empty_indices == [5, 6],
		"rendered grid must show exactly 2 empty slots at indices 5,6 (got %s)" % str(empty_indices)
	)
	var free_cell := _cell_rect(7, display_slots)
	_expect(
		_cell_probe_luma(image, free_cell) > 0.42,
		"the trailing non-consuming cell must render as a filled cell, not an empty slot (luma %.2f)" % _cell_probe_luma(image, free_cell)
	)


func _test_dice_hover_renders_right_panel_colors() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	var permanent: Dictionary = {}
	var sign_flip := 1
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		permanent[stat_key] = 7 * sign_flip
		sign_flip = -sign_flip
	var snapshot := {
		"runtime_skill_levels": {},
		"perk_fusion_display_projection": {
			"entries": [{"type": "mystic_dice", "permanent_raw": permanent, "use_count": 2}],
		},
	}
	# 주사위 셀은 슬롯 비소모라 그리드 후미(6 empty + dice = 7셀, index 6).
	var dice_cell := _cell_rect(6, 7)

	var probe := StatusPanelProbe.new()
	probe.size = VIEW_SIZE
	probe.renderer = renderer
	probe.runtime_state = state
	probe.snapshot = snapshot
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	probe.panel_rect = PANEL_RECT
	probe.view_size = VIEW_SIZE
	_viewport.add_child(probe)

	# [C] 음성 대조(양성과 동일 fixture·타이밍): hover 없음 → dice 고유색 0.
	state.set_status_hover_mouse_pos(Vector2(-1.0, -1.0))
	var image_no_hover: Image = await _capture(probe, "dice_no_hover")
	if image_no_hover == null:
		probe.queue_free()
		_failures.append("no-hover capture must produce a non-empty image")
		return
	# 판정 밴드 = 그리드 행 위쪽(툴팁은 셀 위에 배치됨). 그리드 행 자체는
	# 제외 — 주사위 셀의 실 아이콘 아트에 주황 픽셀이 있어 curse 판별식에
	# 걸리는 정적 위양성이 실측됐다(제외 박스 원칙).
	var tooltip_band := Rect2(0.0, 0.0, VIEW_SIZE.x, PANEL_RECT.position.y + 50.0)
	var benefit_before := _count_color(image_no_hover, tooltip_band, _is_dice_benefit_green)
	var curse_before := _count_color(image_no_hover, tooltip_band, _is_dice_curse_red)
	_expect(benefit_before == 0, "without hover the dice benefit green must not appear (got %d px)" % benefit_before)
	_expect(curse_before == 0, "without hover the dice curse red must not appear (got %d px)" % curse_before)

	# [B] 실 hover 경로: 상태에 마우스 좌표를 실고 다시 그리면
	# _draw_status_panel 내부 hover 판정 → _draw_perk_status_tooltip 실렌더.
	state.set_status_hover_mouse_pos(dice_cell.get_center())
	var image_hover: Image = await _capture(probe, "dice_hover_right_panel")
	probe.queue_free()
	if image_hover == null:
		_failures.append("hover capture must produce a non-empty image")
		return
	var benefit_after := _count_color(image_hover, tooltip_band, _is_dice_benefit_green)
	var curse_after := _count_color(image_hover, tooltip_band, _is_dice_curse_red)
	_expect(benefit_after > 0, "dice hover must render benefit-green stat rows in the right panel (got 0 px)")
	_expect(curse_after > 0, "dice hover must render curse-red stat rows in the right panel (got 0 px)")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
