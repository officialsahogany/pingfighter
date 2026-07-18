extends SceneTree

# 콜드부트 시네마틱 CB4 픽셀 QA 하니스(v2, fail-closed) — 코덱스 지침:
# 독립 호스트가 아니라 "실 배틀 모달 전체"를 렌더한다. 실 구성:
# RuntimePerkOverlayRenderer.draw(백드롭 dim+융합 패널 즉시모드) 캔버스 +
# process_idle(실 모달 게이트)로 생성된 z=110 호스트를 같은 SubViewport
# 캔버스에 태워 라이브 z-순서를 재현한다.
# 반드시 --headless 없이 실행:
#   godot --path godot -s res://tools/perk_fusion_cold_boot_capture.gd
#
# fail-closed 계약: 판정 FAIL·저장/디렉터리/summary 오류·산출물 부재/크기
# 미달·summary readback 불일치 중 하나라도 있으면 exit 1.
# 렌더 경합 차단: 텍스처 읽기 전 RenderingServer.frame_post_draw 대기.
# z-order 증명: 모든 호스트 샷에 패널 테두리/제목 sentinel + 호스트 z를
# 패널 아래로 강제한 음성 대조 샷에서 게이지 시그니처가 사라져야 한다.

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const OUT_ROOT := "C:/Users/woduq/bosspong_backups/qa_evidence"
const MIN_PNG_BYTES := 1000

var _summary_lines: Array[String] = []
var _out_dir := ""


class RegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object

	func _init(state_value: Object, catalog_value: Object) -> void:
		state = state_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
		return null


class ModuleGetterStub:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(name: String) -> Object:
		return modules.get(name, null)


class BackgroundDrawer:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(760.0, 750.0)), Color(0.10, 0.12, 0.17))
		draw_rect(Rect2(380.0, 0.0, 380.0, 750.0), Color(0.16, 0.14, 0.20))
		draw_rect(Rect2(Vector2.ZERO, Vector2(760.0, 750.0)), Color(1.0, 0.0, 1.0, 0.9), false, 2.0)


class ModalCanvas:
	extends Node2D

	var renderer: Object
	var state: Object
	var catalog: Object

	func _draw() -> void:
		if renderer != null and state != null:
			renderer.draw(self, state, catalog, Vector2(760.0, 750.0))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("perk_fusion_cold_boot_capture must run WITHOUT --headless (needs the real renderer)")
		quit(1)
		return
	var commit_full := _git_output(["rev-parse", "HEAD"])
	var commit12 := commit_full.substr(0, 12) if commit_full.length() >= 12 else "nocommit"
	var dirty_fingerprint := _git_output(["status", "--porcelain"]).md5_text()
	_out_dir = "%s/perk_fusion_cold_boot_%d_%d_%s" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id(), commit12]
	if DirAccess.dir_exists_absolute(_out_dir):
		push_error("[ColdBootQA] evidence dir collision (no-clobber): %s" % _out_dir)
		quit(1)
		return
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(_out_dir)
	_check(mkdir_error == OK, "증적 디렉터리 생성(%s, err=%d)" % [_out_dir, mkdir_error])
	_check(commit_full.length() >= 12, "커밋 귀속(HEAD=%s)" % commit_full)
	_summary_lines.append("META commit=%s" % commit_full)
	_summary_lines.append("META dirty_fingerprint_md5=%s" % dirty_fingerprint)

	# [샷 이름, 티어 롤, core 선무장, 호스트 사용, idle 시퀀스, 음성 z 강제]
	var shots := [
		["s0_degraded_b2_immediate", _success_rolls(), false, false, [0.016, 1.30], false],
		["s1_host_b0_dock", _success_rolls(), false, true, [0.016, 0.20], false],
		["s2_host_b2_gauge_success", _success_rolls(), false, true, [0.016, 1.30], false],
		["s3_host_b2_gauge_stutter", _side_effect_rolls(), false, true, [0.016, 1.30], false],
		["s4_host_b2_overshoot_gold", _byproduct_rolls(), false, true, [0.016, 1.75], false],
		["s5_host_b3_ignition_stabilizer", _side_effect_rolls(), true, true, [0.016, 1.90], false],
		["s6_host_b4_reveal_awakened", _byproduct_rolls(), false, true, [0.016, 2.30], false],
		# 음성 대조: 호스트 z를 패널 아래로 강제 — 게이지 시그니처가 패널에
		# 가려져 사라져야 z-order 검출기가 실제로 z를 보고 있음을 증명한다.
		["s8_negative_host_below_panel", _success_rolls(), false, true, [0.016, 1.30], true],
		# B5 핸드오프: B4 후반에서 reveal을 관통하는 idle 한 번 — 같은
		# 프레임에 호스트가 닫히고 리빌 패널이 그려져 단절 프레임이 없다.
		["s7_handoff_reveal", _byproduct_rolls(), false, true, [0.016, 2.60, 0.30], false],
	]
	var captures: Dictionary = {}
	for shot_value: Variant in shots:
		var shot: Array = shot_value as Array
		captures[str(shot[0])] = await _capture_shot(
			str(shot[0]),
			shot[1] as Dictionary,
			bool(shot[2]),
			bool(shot[3]),
			shot[4] as Array,
			bool(shot[5])
		)

	_analyze(captures)

	# 산출물 존재·크기 fail-closed 검사
	for shot_value: Variant in shots:
		var shot_name := str((shot_value as Array)[0])
		var png_path := "%s/%s.png" % [_out_dir, shot_name]
		var exists: bool = FileAccess.file_exists(png_path)
		var size: int = 0
		if exists:
			var png_file := FileAccess.open(png_path, FileAccess.READ)
			if png_file != null:
				size = int(png_file.get_length())
				png_file.close()
		_check(exists and size >= MIN_PNG_BYTES, "산출물 존재·크기(%s, %d bytes)" % [shot_name, size])

	# 산출물 sha256 manifest(귀속 자립)
	for shot_value: Variant in shots:
		var manifest_shot := str((shot_value as Array)[0])
		var manifest_path := "%s/%s.png" % [_out_dir, manifest_shot]
		if FileAccess.file_exists(manifest_path):
			_summary_lines.append("META sha256 %s=%s" % [manifest_shot, FileAccess.get_sha256(manifest_path)])

	var failed := false
	for line: String in _summary_lines:
		if line.begins_with("FAIL"):
			failed = true
	_summary_lines.append("RESULT: %s" % ("FAIL" if failed else "PASS"))

	var summary_path := "%s/summary.txt" % _out_dir
	var out := FileAccess.open(summary_path, FileAccess.WRITE)
	if out == null:
		push_error("[ColdBootQA] summary open failed: %s" % summary_path)
		quit(1)
		return
	for line: String in _summary_lines:
		out.store_line(line)
		print("[ColdBootQA] %s" % line)
	out.close()
	# summary readback fail-closed
	var readback := FileAccess.get_file_as_string(summary_path)
	for line: String in _summary_lines:
		if not readback.contains(line):
			push_error("[ColdBootQA] summary readback mismatch: %s" % line)
			failed = true
	print("[ColdBootQA] evidence: %s" % _out_dir)
	quit(1 if failed else 0)


func _git_output(git_args: Array) -> String:
	var repo_root: String = ProjectSettings.globalize_path("res://").rstrip("/").get_base_dir()
	var output: Array = []
	# 일회성 safe.directory 주입 — 격리 게이트 worktree(임시 경로)에서의
	# dubious-ownership 거부를 우회한다(전역 git config 무접촉).
	var args: Array = ["-c", "safe.directory=*", "-C", repo_root]
	args.append_array(git_args)
	var exit_code: int = OS.execute("git", PackedStringArray(args), output)
	if exit_code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


func _capture_shot(
	shot_name: String,
	rolls: Dictionary,
	pre_own_core: bool,
	use_host: bool,
	idle_deltas: Array,
	force_host_below_panel: bool
) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(GAME_SIZE.x), int(GAME_SIZE.y))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var bg := BackgroundDrawer.new()
	viewport.add_child(bg)
	bg.queue_redraw()

	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"common_swiftness": 5,
		"dash_lightweight": 5,
	}
	if pre_own_core:
		state.commit_perk_fusion(
			["common_swiftness", "dash_lightweight"],
			{"outcome": "byproduct", "byproducts": ["core_stabilize"]},
			catalog
		)
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [{
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": ["item_luck", "common_bulk_up"],
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	state.selected_index = 0
	state.choose_selected(null, registry, GAME_SIZE)
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	state._perk_fusion_modal_flow.confirm_current()
	state._confirm_perk_fusion_modal(null, registry, rolls)

	var canvas := ModalCanvas.new()
	canvas.renderer = RuntimePerkOverlayRenderer.new()
	canvas.renderer.prewarm_assets()
	canvas.state = state
	canvas.catalog = catalog
	viewport.add_child(canvas)

	var getter := ModuleGetterStub.new()
	getter.modules = {
		"runtime_perk_state": state,
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
	}
	var controller := BattleSceneOverlayFrameController.new()
	var host_z_forced := false
	for delta_value: Variant in idle_deltas:
		if use_host:
			controller.process_idle(float(delta_value), bg, registry, Callable(getter, "get_module"))
			if force_host_below_panel and not host_z_forced:
				var host_value: Variant = state.get("_cold_boot_cinematic_host")
				if host_value is Node2D and is_instance_valid(host_value):
					# 음성 대조 전용: 프로덕션 z=110을 캔버스 아래로 강제.
					(host_value as Node2D).z_index = -50
					host_z_forced = true
		else:
			state.update(float(delta_value), GAME_SIZE, null, registry)
		canvas.queue_redraw()
		await process_frame
	for _settle: int in range(3):
		canvas.queue_redraw()
		await process_frame
	# 렌더 경합 차단: 마지막 드로가 실제로 래스터화된 뒤에 읽는다.
	await RenderingServer.frame_post_draw

	var image: Image = viewport.get_texture().get_image()
	var save_error: Error = image.save_png("%s/%s.png" % [_out_dir, shot_name])
	_check(save_error == OK, "PNG 저장(%s, err=%d)" % [shot_name, save_error])
	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return image


func _analyze(captures: Dictionary) -> void:
	# 모든 샷(호스트/무호스트/음성/핸드오프)에서 모달 패널 테두리+제목
	# sentinel — 렌더 경합으로 패널이 통째로 빠진 프레임을 fail-closed로
	# 잡는다.
	for shot_name: String in captures.keys():
		var image: Image = captures.get(shot_name) as Image
		var border_pixels := _count_panel_border_pixels(image)
		var title_pixels := _count_title_pixels(image)
		_check(border_pixels > 40, "%s: 모달 패널 테두리 sentinel(%d px)" % [shot_name, border_pixels])
		_check(title_pixels > 30, "%s: 모달 제목 sentinel(%d px)" % [shot_name, title_pixels])

	var immediate_in_degraded := _scan_immediate_orange(captures.get("s0_degraded_b2_immediate") as Image)
	_check(immediate_in_degraded > 0, "degraded(무호스트) 샷에 즉시모드 오렌지 시그니처 존재(%d px) — 폴백 실렌더" % immediate_in_degraded)
	for host_shot: String in ["s2_host_b2_gauge_success", "s3_host_b2_gauge_stutter", "s4_host_b2_overshoot_gold", "s5_host_b3_ignition_stabilizer", "s6_host_b4_reveal_awakened"]:
		var orange_count := _scan_immediate_orange(captures.get(host_shot) as Image)
		_check(orange_count == 0, "%s: 즉시모드 오렌지 시그니처 부재(%d px) — 이중 드로 없음" % [host_shot, orange_count])

	# z-order 증명: 양성(호스트 위) 게이지 시그니처 다량 + 음성(z 강제
	# 하향) 소멸 — 검출기가 실제 z를 본다.
	var gauge_cyan := _scan_gauge_cyan(captures.get("s2_host_b2_gauge_success") as Image)
	_check(gauge_cyan > 300, "성공 부팅 게이지 시안 세그먼트 렌더(%d px)" % gauge_cyan)
	var gauge_cyan_negative := _scan_gauge_cyan(captures.get("s8_negative_host_below_panel") as Image)
	_check(
		gauge_cyan_negative < maxi(20, gauge_cyan / 20),
		"음성 대조(z 하향): 게이지 시그니처 소멸(%d px < %d) — z-order 검출 실증" % [gauge_cyan_negative, maxi(20, gauge_cyan / 20)]
	)

	var overshoot_gold := _scan_color_band(captures.get("s4_host_b2_overshoot_gold") as Image, 0.80, 1.01, 0.55, 0.90, 0.05, 0.45)
	_check(overshoot_gold > 0, "부산물 오버슈트 골드 링 렌더(%d px)" % overshoot_gold)
	var awakened: Image = captures.get("s6_host_b4_reveal_awakened") as Image
	var awakened_center: Color = awakened.get_pixel(int(GAME_SIZE.x * 0.5), int(GAME_SIZE.y * 0.5))
	_check(
		awakened_center.v > 0.15 and awakened_center.v < 0.95 and awakened_center.r > awakened_center.b,
		"s6: 각성 코어 warm 점등(v=%.2f, r=%.2f>b=%.2f)" % [awakened_center.v, awakened_center.r, awakened_center.b]
	)

	# B5 핸드오프 단절 없음: reveal 관통 프레임에 호스트 게이지는 사라지고
	# 리빌 "본문"이 실제로 그려져 있다 — 빈 패널 셸(테두리+제목만)로는
	# 통과 불가하도록 reveal 전용 ROI 3종(융합 아이콘/부산물 골드 로그/계속
	# 힌트)을 함께 검사한다.
	var handoff: Image = captures.get("s7_handoff_reveal") as Image
	var handoff_gauge := _scan_gauge_cyan(handoff)
	_check(handoff_gauge < 20, "핸드오프 프레임: 호스트 게이지 소멸(%d px) — 리빌 패널로 인계" % handoff_gauge)
	var reveal_icon := _scan_region_band(handoff, 340, 420, 120, 200, 0.10, 0.70, 0.55, 0.98, 0.75, 1.01)
	_check(reveal_icon > 30, "핸드오프 프레임: 리빌 융합 아이콘 렌더(%d px)" % reveal_icon)
	var reveal_log_gold := _scan_region_band(handoff, 200, 560, 258, 302, 0.78, 1.01, 0.52, 0.90, 0.00, 0.48)
	_check(reveal_log_gold > 15, "핸드오프 프레임: 부산물 골드 로그 렌더(%d px)" % reveal_log_gold)
	var reveal_hint := _scan_region_band(handoff, 545, 748, 662, 706, 0.70, 1.01, 0.70, 1.01, 0.70, 1.01)
	_check(reveal_hint > 12, "핸드오프 프레임: 계속 힌트 렌더(%d px)" % reveal_hint)

	var degraded: Image = captures.get("s0_degraded_b2_immediate") as Image
	var corner: Color = degraded.get_pixel(8, 8)
	_check(corner.v < 0.09, "백드롭 dim 적용(모서리 v=%.2f < 원배경 0.12)" % corner.v)


func _scan_immediate_orange(image: Image) -> int:
	# 즉시모드 시그니처: draw_circle(right_center, Color(1.0, 0.64, 0.30, 0.75)).
	# 알파 0.75 블렌드라 r이 0.85 미만으로 눌린다 — 호스트의 스터터 앰버
	# (FAULT→GOLD lerp, 사실상 불투명 아크라 r>=0.85)와 R 상한으로 분리.
	return _scan_color_band(image, 0.66, 0.85, 0.40, 0.60, 0.16, 0.38)


func _scan_gauge_cyan(image: Image) -> int:
	# 게이지 링 annulus(r 80~112)로 제한 — 모달 테두리 프레임(둘레 ~1500px)과
	# 리빌 패널의 융합 아이콘 시안 디스크(중심에서 ~180~210px)가 카운트를
	# 오염시키는 것을 모두 차단한다(호스트 게이지 링 반경=96).
	if image == null:
		return -1
	var center := Vector2(760.0, 750.0) * 0.5
	var count := 0
	for y in range(int(center.y) - 120, int(center.y) + 120, 2):
		for x in range(int(center.x) - 120, int(center.x) + 120, 2):
			var radius: float = Vector2(float(x), float(y)).distance_to(center)
			if radius < 80.0 or radius > 112.0:
				continue
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r >= 0.10 and pixel.r < 0.55 and pixel.g >= 0.55 and pixel.g < 0.95 and pixel.b >= 0.80:
				count += 1
	return count


func _count_panel_border_pixels(image: Image) -> int:
	# 융합 패널 테두리(밝은 시안-블루 프레임, 상단 y≈20~45 대역 가로선).
	if image == null:
		return -1
	var count := 0
	for y in range(20, 46):
		for x in range(0, image.get_width(), 2):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r < 0.55 and pixel.g >= 0.45 and pixel.b >= 0.70:
				count += 1
	return count


func _count_title_pixels(image: Image) -> int:
	# 상단 중앙 제목("융합 중..." / 리빌 타이틀) — 근백색 텍스트만. 상단
	# 테두리 라인(y≈29, 파랑 r<0.55)을 ROI에서 제외(y>=38)하고 무채색 조건
	# (r>0.70)으로 이중 차단 — 제목이 없으면 테두리만으로는 통과 불가.
	if image == null:
		return -1
	var count := 0
	for y in range(38, 116):
		for x in range(200, 561, 2):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.v > 0.82 and pixel.r > 0.70:
				count += 1
	return count


func _scan_region_band(
	image: Image,
	x_min: int,
	x_max: int,
	y_min: int,
	y_max: int,
	r_min: float,
	r_max: float,
	g_min: float,
	g_max: float,
	b_min: float,
	b_max: float
) -> int:
	if image == null:
		return -1
	var count := 0
	for y in range(y_min, y_max):
		for x in range(x_min, x_max, 2):
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= r_min and pixel.r < r_max
				and pixel.g >= g_min and pixel.g < g_max
				and pixel.b >= b_min and pixel.b < b_max
			):
				count += 1
	return count


func _scan_color_band(image: Image, r_min: float, r_max: float, g_min: float, g_max: float, b_min: float, b_max: float) -> int:
	if image == null:
		return -1
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= r_min and pixel.r < r_max
				and pixel.g >= g_min and pixel.g < g_max
				and pixel.b >= b_min and pixel.b < b_max
			):
				count += 1
	return count


func _check(passed: bool, message: String) -> void:
	_summary_lines.append("%s %s" % ["PASS" if passed else "FAIL", message])


func _success_rolls() -> Dictionary:
	return {
		"outcome": 0.0,
		"magnitude": [0.7, 0.7],
		"lane_selection": [0.0, 0.5],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0, 0.0],
	}


func _side_effect_rolls() -> Dictionary:
	var rolls := _success_rolls()
	rolls["outcome"] = 0.60
	return rolls


func _byproduct_rolls() -> Dictionary:
	var rolls := _success_rolls()
	rolls["outcome"] = 0.90
	return rolls
