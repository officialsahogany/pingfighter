extends SceneTree

# 캐릭터 정보창 개편(7/9 소실 최종본 복원) 픽셀 QA 하니스 — 실 draw()
# 관통 캡처. 반드시 --headless 없이 실행:
#   godot --path godot -s res://tools/character_info_redesign_capture.gd
# fail-closed: 판정 FAIL·산출물 부재/미달·귀속 실패 시 exit 1.
# 기준 해상도 = 사용자 지정 기준 PNG(KakaoTalk 7/9 04:07) 실측 1264x964.
# 프로그램 판정: 섹션 앵커(은퇴 rect 0·능력치 하단 확장·링펫 우열),
# 액티브 스트립/휴지통 부재, 실 prewarm 경유 스킬 아이콘·헤더 문장·
# 링펫 전신 아트 도달.

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const CharacterInfoOverlayDragController := preload("res://scripts/hud/character_info_overlay_drag_controller.gd")

const VIEW_SIZE := Vector2(1264.0, 964.0)
const OUT_ROOT := "C:/Users/woduq/bosspong_backups/qa_evidence"
const MIN_PNG_BYTES := 20000

var _summary_lines: Array[String] = []
var _out_dir := ""


class PermissiveOwner:
	extends RefCounted

	var fields: Dictionary = {}

	func _init(initial: Dictionary) -> void:
		fields = initial.duplicate(true)

	func _get(property: StringName) -> Variant:
		return fields.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		fields[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


class RegistryStub:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		return modules.get(key, null)


class CharacterRuntimeStub:
	extends RefCounted

	func get_base_movement_config(_character_type: String) -> Dictionary:
		return {"paddle_speed": 6.0, "paddle_max_speed": 6.0}


class OverlayCanvas:
	extends Node2D

	var overlay: Object
	var owner_ref: Object
	var registry_ref: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1264.0, 964.0)), Color(0.07, 0.09, 0.14))
		if overlay != null:
			overlay.draw(self, owner_ref, registry_ref, Vector2(1264.0, 964.0))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("character_info_redesign_capture must run WITHOUT --headless")
		quit(1)
		return
	LanguageSettings.set_test_locale_override("ko")
	var head_query := _git_query(["rev-parse", "HEAD"])
	var commit_full := str(head_query.get("text", ""))
	var commit12 := commit_full.substr(0, 12) if commit_full.length() >= 12 else "nocommit"
	_out_dir = "%s/character_info_redesign_%d_%d_%s" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id(), commit12]
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(_out_dir)
	_check(mkdir_error == OK, "증적 디렉터리 생성(err=%d)" % mkdir_error)
	_check(bool(head_query.get("ok", false)) and commit_full.length() >= 12, "커밋 귀속(HEAD=%s)" % commit_full)
	_summary_lines.append("META commit=%s" % commit_full)

	var base_result: Dictionary = await _capture_shot("s1_base_smasher", false)
	var lingpet_result: Dictionary = await _capture_shot("s2_companion_maribo", true)
	var base_image: Image = base_result.get("image")
	var lingpet_image: Image = lingpet_result.get("image")

	# [판정 1] 기준 해상도 렌더(기준 PNG 1264x964와 동일 캔버스).
	for named: Array in [["s1", base_image], ["s2", lingpet_image]]:
		var shot_image: Image = named[1]
		_check(
			shot_image != null and shot_image.get_width() == int(VIEW_SIZE.x) and shot_image.get_height() == int(VIEW_SIZE.y),
			"%s: 기준 해상도 1264x964 렌더" % named[0]
		)

	# [판정 2] 섹션 앵커 — 실 draw가 남긴 레이아웃 rect를 직접 검사한다.
	for named: Array in [["s1", base_result], ["s2", lingpet_result]]:
		var overlay: Object = (named[1] as Dictionary).get("overlay")
		var panel: Rect2 = overlay._layout_panel_rect
		_check(panel.size != Vector2.ZERO, "%s: 패널 rect 산출" % named[0])
		_check(overlay._layout_equipment_rect == Rect2(), "%s: 장비 슬롯 zero-hidden" % named[0])
		_check(overlay._layout_inventory_rect == Rect2(), "%s: 패시브 보관함 zero-hidden" % named[0])
		_check(overlay._layout_active_items_rect == Rect2(), "%s: 액티브 스트립 zero-hidden(기준 PNG 권위)" % named[0])
		var stats: Rect2 = overlay._layout_stats_rect
		var lingpet_rect: Rect2 = overlay._layout_lingpet_rect
		var lingpet_stats: Rect2 = overlay._layout_lingpet_stats_rect
		_check(stats.end.y > panel.end.y - 90.0, "%s: 능력치 패널 하단 확장(스트립 부재)" % named[0])
		_check(lingpet_rect.position.x > panel.position.x + panel.size.x * 0.55, "%s: 링펫 우측 열 앵커" % named[0])
		_check(lingpet_stats.end.y > panel.end.y - 90.0 and lingpet_stats.position.x == lingpet_rect.position.x, "%s: 링펫 능력치 박스 하단 앵커" % named[0])
		# [판정 2b] 기준 PNG(1264x964) 실측 절대 좌표(±6/±8px) — 외곽 패널과
		# 전 섹션 박스의 절대 기하가 기준과 일치해야 한다(코덱스 P1: 상대
		# 앵커만으로는 전체화면 패널·압축 분할도 통과했다).
		var skill_rect: Rect2 = overlay._layout_skill_rect
		var perk_rect: Rect2 = overlay._layout_perk_rect
		_check_near(named[0], "패널 상단", panel.position.y, 22.0, 6.0)
		_check_near(named[0], "패널 하단", panel.end.y, 951.0, 6.0)
		_check_near(named[0], "스킬 섹션 x", skill_rect.position.x, 44.0, 6.0)
		_check_near(named[0], "스킬 섹션 상단", skill_rect.position.y, 84.0, 6.0)
		_check_near(named[0], "스킬 섹션 하단", skill_rect.end.y, 381.0, 8.0)
		_check_near(named[0], "퍽 섹션 상단", perk_rect.position.y, 410.0, 8.0)
		_check_near(named[0], "퍽 섹션 하단", perk_rect.end.y, 621.0, 8.0)
		_check_near(named[0], "능력치 상단", stats.position.y, 650.0, 6.0)
		_check_near(named[0], "능력치 하단", stats.end.y, 930.0, 8.0)
		_check_near(named[0], "링펫 열 좌변", lingpet_rect.position.x, 871.0, 8.0)
		_check_near(named[0], "링펫 박스 하단", lingpet_rect.end.y, 749.0, 8.0)
		_check_near(named[0], "링펫 능력치 상단", lingpet_stats.position.y, 761.0, 8.0)
		_check_near(named[0], "링펫 능력치 하단", lingpet_stats.end.y, 939.0, 8.0)
		# [판정 3] 휴지통 부재: 드래그 소스 게이트 + 우상단 픽셀 무광.
		_check(not CharacterInfoOverlayDragController.should_show_trash(overlay), "%s: 휴지통 게이트 은닉" % named[0])
		var trash_rect: Rect2 = CharacterInfoOverlayDragController.compute_trash_rect(panel)
		var trash_glyph := _count_region_bright(named[1].get("image"), trash_rect, 0.55)
		_check(trash_glyph <= 6, "%s: 우상단 휴지통 글리프 부재(%d px)" % [named[0], trash_glyph])

	# [판정 4] 실 prewarm 도달 — 스킬 카드 실아이콘(채도 잉크), 헤더 문장.
	var base_overlay: Object = base_result.get("overlay")
	var icon_rects: Array = base_overlay._skill_slot_icon_rect_cache
	_check(icon_rects.size() > 0, "s1: 스킬 카드 레이아웃 캐시 산출")
	if icon_rects.size() > 0:
		var first_icon_ink := _count_region_saturated(base_image, icon_rects[0] as Rect2)
		_check(first_icon_ink > 40, "s1: 1번 스킬 카드 실아이콘 도달(%d px)" % first_icon_ink)
	var crest_panel: Rect2 = base_overlay._layout_panel_rect
	var crest_ink := _count_region_saturated(base_image, Rect2(crest_panel.position + Vector2(18.0, 12.0), Vector2(56.0, 56.0)))
	_check(crest_ink > 25, "s1: 헤더 방패 문장 도달(%d px)" % crest_ink)

	# [판정 5] 링펫 전신 아트 도달(실 prewarm 경유 텍스처 캐시+아트 잉크).
	var lp_overlay: Object = lingpet_result.get("overlay")
	_check((lp_overlay._lingpet_art_texture_cache as Dictionary).size() > 0, "s2: 링펫 아트 텍스처 캐시 적재(스테이지드 프리웜 완주)")
	var lp_rect: Rect2 = lp_overlay._layout_lingpet_rect
	var art_probe := Rect2(lp_rect.position + lp_rect.size * Vector2(0.15, 0.25), lp_rect.size * Vector2(0.7, 0.45))
	var art_ink := _count_region_saturated(lingpet_image, art_probe)
	_check(art_ink > 150, "s2: 링펫 전신 아트 잉크 도달(%d px)" % art_ink)

	for shot_name: String in ["s1_base_smasher", "s2_companion_maribo"]:
		var png_path := "%s/%s.png" % [_out_dir, shot_name]
		var size := 0
		if FileAccess.file_exists(png_path):
			var f := FileAccess.open(png_path, FileAccess.READ)
			if f != null:
				size = int(f.get_length())
				f.close()
		_check(size >= MIN_PNG_BYTES, "산출물 존재·크기(%s, %d)" % [shot_name, size])

	var failed := false
	for line: String in _summary_lines:
		if line.begins_with("FAIL"):
			failed = true
	_summary_lines.append("RESULT: %s" % ("FAIL" if failed else "PASS"))
	var out := FileAccess.open("%s/summary.txt" % _out_dir, FileAccess.WRITE)
	if out == null:
		quit(1)
		return
	for line: String in _summary_lines:
		out.store_line(line)
		print("[CIRedesignQA] %s" % line)
	out.close()
	LanguageSettings.set_test_locale_override("")
	print("[CIRedesignQA] evidence: %s" % _out_dir)
	quit(1 if failed else 0)


func _capture_shot(shot_name: String, with_companion: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var perk_state: Object = RuntimePerkState.new()
	perk_state.runtime_skill_levels = {
		"common_swiftness": 5,
		"common_bulk_up": 4,
		"dash_lightweight": 3,
		"item_luck": 2,
		"item_cooldown_mastery": 2,
		"common_training": 1,
		"dash_acceleration": 2,
		"common_refresh": 2,
	}
	var catalog: Object = RuntimePerkCatalog.new()
	var icon_renderer: Object = RuntimePerkIconRenderer.new()
	var skill_config: Object = SmasherSkillConfig.new()
	var registry := RegistryStub.new()
	registry.modules = {
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": catalog,
		"runtime_perk_icon_renderer": icon_renderer,
		"smasher_skill_config": skill_config,
	}
	var owner := PermissiveOwner.new({
		"selected_character_type": "smasher",
		"special_gauge": 120.0,
		"special_gauge_max": 500.0,
		"player_paddle_width": 155.0,
		"active_item_slots": [],
		"show_character_info": true,
	})
	if with_companion:
		var lingpet_runtime: Object = LingpetEggRuntime.new()
		lingpet_runtime._affinity_state.set_run_ring_core_tier(2)
		lingpet_runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1)
		lingpet_runtime.update(0.0, owner, registry)

	var overlay: Object = CharacterInfoOverlay.new()
	# 실 prewarm 경유(코덱스 P1: 방패 문장·실 스킬 아이콘·링펫 전신 아트가
	# 이 경로로만 적재된다) — TAB 오픈과 같은 진입 계약.
	overlay.prewarm_assets(owner, registry, Callable(), true, VIEW_SIZE, ["maribo"] if with_companion else null)
	if with_companion:
		# 링펫 전신 아트/스킬 아이콘 실로드는 스테이지드 프리웜 루프 소유
		# (prewarm_cached_*는 조회 전용) — TAB 오픈의 프레임 분할 로드를
		# 하니스에서는 완주시킨다.
		var lingpet_prewarm_guard := 0
		while not overlay.prewarm_lingpet_panel_assets_step(["maribo"]) and lingpet_prewarm_guard < 400:
			lingpet_prewarm_guard += 1
	overlay.set("active", true)
	overlay.set("animation_time", 10.0)
	var canvas := OverlayCanvas.new()
	canvas.overlay = overlay
	canvas.owner_ref = owner
	canvas.registry_ref = registry
	viewport.add_child(canvas)
	for _i in range(4):
		canvas.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var save_error: Error = image.save_png("%s/%s.png" % [_out_dir, shot_name])
	_check(save_error == OK, "PNG 저장(%s, err=%d)" % [shot_name, save_error])
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return {"image": image, "overlay": overlay}


# 영역 내 밝은 픽셀(v>threshold) — 휴지통 글리프 부재 판정용.
func _count_region_bright(image: Image, rect: Rect2, threshold: float) -> int:
	if image == null:
		return -1
	var count := 0
	var x0: int = clampi(int(rect.position.x), 0, image.get_width() - 1)
	var y0: int = clampi(int(rect.position.y), 0, image.get_height() - 1)
	var x1: int = clampi(int(rect.end.x), 0, image.get_width())
	var y1: int = clampi(int(rect.end.y), 0, image.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if image.get_pixel(x, y).v > threshold:
				count += 1
	return count


# 영역 내 채도 잉크(s>0.3 && v>0.45) — 실아이콘/아트 도달 판정용(패널
# 크롬은 저채도 네이비/시안 라인이라 걸리지 않는다).
func _count_region_saturated(image: Image, rect: Rect2) -> int:
	if image == null:
		return -1
	var count := 0
	var x0: int = clampi(int(rect.position.x), 0, image.get_width() - 1)
	var y0: int = clampi(int(rect.position.y), 0, image.get_height() - 1)
	var x1: int = clampi(int(rect.end.x), 0, image.get_width())
	var y1: int = clampi(int(rect.end.y), 0, image.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.s > 0.3 and pixel.v > 0.45:
				count += 1
	return count


func _count_band(image: Image, r_min: float, r_max: float, g_min: float, g_max: float, b_min: float, b_max: float) -> int:
	if image == null:
		return -1
	var count := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= r_min and pixel.r < r_max
				and pixel.g >= g_min and pixel.g < g_max
				and pixel.b >= b_min and pixel.b < b_max
			):
				count += 1
	return count


func _git_query(git_args: Array) -> Dictionary:
	var repo_root: String = ProjectSettings.globalize_path("res://").rstrip("/").get_base_dir()
	var output: Array = []
	var args: Array = ["-c", "safe.directory=*", "-C", repo_root]
	args.append_array(git_args)
	var exit_code: int = OS.execute("git", PackedStringArray(args), output)
	var text := ""
	if not output.is_empty():
		text = str(output[0]).strip_edges()
	return {"ok": exit_code == 0, "text": text, "exit_code": exit_code}


func _check(passed: bool, message: String) -> void:
	_summary_lines.append("%s %s" % ["PASS" if passed else "FAIL", message])


# 기준 PNG 실측 절대 좌표 판정(허용범위 px 명시).
func _check_near(shot: String, label: String, actual: float, expected: float, tolerance: float) -> void:
	_check(
		absf(actual - expected) <= tolerance,
		"%s: %s 절대 기하(%.1f vs 기준 %.1f, ±%.0f)" % [shot, label, actual, expected, tolerance]
	)
