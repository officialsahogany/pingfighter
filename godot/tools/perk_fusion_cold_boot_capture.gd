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
	var env_pollution := _detect_git_env_pollution()
	_check(env_pollution == "", "GIT_* env 오염 없음(%s)" % (env_pollution if env_pollution != "" else "clean"))
	var head_query: Dictionary = _git_query(["rev-parse", "HEAD"])
	var commit_full := str(head_query.get("text", ""))
	var commit12 := commit_full.substr(0, 12) if commit_full.length() >= 12 else "nocommit"
	var porcelain_query: Dictionary = _git_query(["status", "--porcelain"])
	_check(bool(porcelain_query.get("ok", false)), "dirty 상태 조회 성공(exit 분리 — 실패는 clean과 다르다)")
	var porcelain_text := str(porcelain_query.get("text", ""))
	var dirty_fingerprint := "clean" if porcelain_text.is_empty() else porcelain_text.md5_text()
	var diff_query: Dictionary = _git_query(["diff", "HEAD"])
	_check(bool(diff_query.get("ok", false)), "dirty 내용 조회 성공")
	var dirty_content_fingerprint := "clean" if str(diff_query.get("text", "")).is_empty() else str(diff_query.get("text", "")).md5_text()
	_out_dir = "%s/perk_fusion_cold_boot_%d_%d_%s" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id(), commit12]
	if DirAccess.dir_exists_absolute(_out_dir):
		push_error("[ColdBootQA] evidence dir collision (no-clobber): %s" % _out_dir)
		quit(1)
		return
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(_out_dir)
	_check(mkdir_error == OK, "증적 디렉터리 생성(%s, err=%d)" % [_out_dir, mkdir_error])
	_check(bool(head_query.get("ok", false)) and commit_full.length() >= 12, "커밋 귀속(HEAD=%s)" % commit_full)
	_summary_lines.append("META commit=%s" % commit_full)
	_summary_lines.append("META dirty_status_fingerprint=%s" % dirty_fingerprint)
	_summary_lines.append("META dirty_content_fingerprint=%s" % dirty_content_fingerprint)

	# [샷 이름, 티어 롤, core 선무장, 호스트 사용, idle 시퀀스, 음성 z 강제,
	#  기대 부산물 카운트(-1=검사 안 함 — record 파생 fixture 실검증)]
	var shots := [
		["p0_selection_chrome", _success_rolls(), false, false, [0.016], false, -1, false, false, "selection"],
		["p1_confirmation_chrome", _success_rolls(), false, false, [0.016], false, -1, false, false, "confirmation"],
		["s0_degraded_b2_immediate", _success_rolls(), false, false, [0.016, 1.30], false, -1],
		["s1_host_b0_dock", _success_rolls(), false, true, [0.016, 0.20], false, -1],
		["s2_host_b2_gauge_success", _success_rolls(), false, true, [0.016, 1.30], false, -1],
		["s3_host_b2_gauge_stutter", _side_effect_rolls(), false, true, [0.016, 1.30], false, -1],
		["s4_host_b2_overshoot_gold", _byproduct_rolls(), false, true, [0.016, 1.75], false, -1],
		["s5_host_b3_ignition_stabilizer", _side_effect_rolls(), true, true, [0.016, 1.90], false, -1],
		["s6_host_b4_reveal_awakened", _byproduct_rolls(), false, true, [0.016, 2.30], false, -1],
		# 음성 대조: 호스트 z를 패널 아래로 강제 — 게이지 시그니처가 패널에
		# 가려져 사라져야 z-order 검출기가 실제로 z를 보고 있음을 증명한다.
		["s8_negative_host_below_panel", _success_rolls(), false, true, [0.016, 1.30], true, -1],
		# B5 핸드오프: B4 후반에서 reveal을 관통하는 idle 한 번 — 같은
		# 프레임에 호스트가 닫히고 리빌 패널이 그려져 단절 프레임이 없다.
		["s7_handoff_reveal", _byproduct_rolls(), false, true, [0.016, 2.60, 0.30], false, -1],
		["s19_skip_to_reveal", _side_effect_rolls(), false, true, [0.016], false, -1, false, true],
		# [P1-2] 각성 모듈 전개: 부산물 1/2/3개 카운트 구동 + SNAP OPEN
		# (초기 프레임≪완전 전개). s13=success 동시각 베이스라인(모듈 0).
		["s9_deploy_count1", _byproduct_rolls_with_count(0.0, [0.0]), false, true, [0.016, 2.58], false, 1],
		["s10_deploy_count2", _byproduct_rolls_with_count(0.40, [0.0, 0.0]), false, true, [0.016, 2.58], false, 2],
		["s11_deploy_count3", _byproduct_rolls_with_count(0.99, [0.0, 0.0, 0.0]), false, true, [0.016, 2.58], false, 3],
		["s12_deploy_early_snap", _byproduct_rolls_with_count(0.99, [0.0, 0.0, 0.0]), false, true, [0.016, 2.05], false, 3],
		["s13_reveal_success_baseline", _success_rolls(), false, true, [0.016, 2.58], false, 0],
		# CB4c-2 스파크: 벤트 팬(부작용, B3 진입 직후)·골드 샤워(부산물,
		# B4 진입 직후) — fixed seed, 캡처는 발화 후 수 프레임 안.
		["s14_vent_sparks_side_effect", _side_effect_rolls(), false, true, [0.016, 1.84, 0.03, 0.03], false, 0],
		["s15_gold_shower_byproduct", _byproduct_rolls(), false, true, [0.016, 2.05, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02], false, 1],
		# 샤워 침묵 대조는 s15와 "같은 타이밍"의 success 샷이 소유한다 —
		# s13(2.58 단발 틱)은 발화 직후 페이드-인 알파 구간이라 항상-발화
		# 버그도 안 보여 반증이 공허해진다(FV-A 실측).
		["s16_shower_silent_success", _success_rolls(), false, true, [0.016, 2.05, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02], false, 0],
		# [P2-1] 스테일 재사용 프로브: 부작용 모달에서 벤트 발화(B3) 직후
		# finish → 같은 호스트로 무발화 success 모달 즉시 재개 — 하드
		# 클리어가 없으면 수명(0.85s) 안의 생존 스파크가 이월 노출된다.
		["s17_stale_reuse_success", _side_effect_rolls(), false, true, [0.016, 1.84], false, 0, true],
		# CB4c-3: s12(전개 초기, B4 progress 0.023)와 "동시각" success
		# 베이스라인 — B4 초입 haze 잔광이 모듈 annulus에 얹히므로, 초기
		# 잉크 차분은 잔광까지 같은 조건의 쌍으로 계산해야 한다(잔광 없는
		# s13(progress 0.78) 차분은 타이밍 불일치로 오염).
		["s18_success_early_baseline", _success_rolls(), false, true, [0.016, 2.05], false, 0],
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
			bool(shot[5]),
			int(shot[6]),
			bool(shot[7]) if shot.size() > 7 else false,
			bool(shot[8]) if shot.size() > 8 else false,
			str(shot[9]) if shot.size() > 9 else ""
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


# git 질의(P3 보강): 종료코드를 결과와 분리해 "실패"와 "clean 빈 출력"이
# 합쳐지지 않게 한다. 임시 인덱스 커밋 절차의 GIT_INDEX_FILE 등이 남아
# 있으면 질의가 다른 인덱스를 볼 수 있어 오염을 fail-closed로 거부한다.
func _detect_git_env_pollution() -> String:
	for env_key: String in ["GIT_INDEX_FILE", "GIT_DIR", "GIT_WORK_TREE"]:
		if OS.has_environment(env_key):
			return env_key
	return ""


func _git_query(git_args: Array) -> Dictionary:
	var repo_root: String = ProjectSettings.globalize_path("res://").rstrip("/").get_base_dir()
	var output: Array = []
	# 일회성 safe.directory 주입 — 격리 게이트 worktree(임시 경로)에서의
	# dubious-ownership 거부를 우회한다(전역 git config 무접촉).
	var args: Array = ["-c", "safe.directory=*", "-C", repo_root]
	args.append_array(git_args)
	var exit_code: int = OS.execute("git", PackedStringArray(args), output)
	var text := ""
	if not output.is_empty():
		text = str(output[0]).strip_edges()
	return {"ok": exit_code == 0, "text": text, "exit_code": exit_code}


func _capture_shot(
	shot_name: String,
	rolls: Dictionary,
	pre_own_core: bool,
	use_host: bool,
	idle_deltas: Array,
	force_host_below_panel: bool,
	expected_byproduct_count: int,
	stale_reuse_probe: bool = false,
	skip_to_reveal_probe: bool = false,
	chrome_phase: String = ""
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
	if chrome_phase != "selection":
		state._perk_fusion_modal_flow.select_source_at(1)
		state._perk_fusion_modal_flow.confirm_current()
	if chrome_phase.is_empty():
		state._confirm_perk_fusion_modal(null, registry, rolls)
		if skip_to_reveal_probe:
			state._confirm_perk_fusion_modal(null, registry)
	if expected_byproduct_count >= 0:
		var committed_check: Dictionary = (
			state.get_perk_fusion_modal_snapshot().get("cold_boot", {}) as Dictionary
		).get("committed_record", {}) as Dictionary
		var byproduct_count: int = (committed_check.get("byproducts", []) as Array).size()
		_check(
			byproduct_count == expected_byproduct_count,
			"%s: 부산물 카운트 fixture 실검증(%d == %d)" % [shot_name, byproduct_count, expected_byproduct_count]
		)

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
	if stale_reuse_probe:
		# 발화 모달 finish → 같은 state/호스트로 무발화 success 모달 재개
		# (첫 모달이 재료를 소비했으므로 남은 만렙 쌍 사용).
		state._confirm_perk_fusion_modal(null, registry)
		state._confirm_perk_fusion_modal(null, registry)
		state.pending_skill_choices = 1
		state.choice_active = true
		state.animation_time = 10.0
		state.current_choice_context = {"source": "battle_starpoint"}
		state.current_choices = [{
			"id": "perk_fusion",
			"name": "퍽 융합",
			"is_perk_fusion": true,
			"eligible_sources": ["common_swiftness", "dash_lightweight"],
			"offer_lane": "fusion",
			"offer_protected": true,
		}]
		state.selected_index = 0
		state.choose_selected(null, registry, GAME_SIZE)
		state._perk_fusion_modal_flow.select_source_at(0)
		state._perk_fusion_modal_flow.select_source_at(1)
		state._perk_fusion_modal_flow.confirm_current()
		state._confirm_perk_fusion_modal(null, registry, _success_rolls())
		controller.process_idle(0.05, bg, registry, Callable(getter, "get_module"))
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

	var immediate_in_degraded := _scan_immediate_fallback_jade(captures.get("s0_degraded_b2_immediate") as Image)
	_check(immediate_in_degraded > 2000, "degraded(무호스트) 샷에 즉시모드 옥빛 재료구 시그니처 존재(%d px) — 폴백 실렌더" % immediate_in_degraded)
	var host_immediate_max := 0
	for host_shot: String in ["s2_host_b2_gauge_success", "s3_host_b2_gauge_stutter", "s4_host_b2_overshoot_gold", "s5_host_b3_ignition_stabilizer", "s6_host_b4_reveal_awakened"]:
		var fallback_jade_count := _scan_immediate_fallback_jade(captures.get(host_shot) as Image)
		host_immediate_max = maxi(host_immediate_max, fallback_jade_count)
	_check(
		immediate_in_degraded > host_immediate_max * 3,
		"degraded 폴백 옥빛 재료구가 텍스처 호스트보다 우세(%d px > %d px * 3) — 이중 드로 없음" % [immediate_in_degraded, host_immediate_max]
	)

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
	var reveal_icon := _scan_region_band(handoff, 340, 420, 120, 200, 0.18, 0.62, 0.58, 1.01, 0.48, 0.94)
	_check(reveal_icon > 30, "핸드오프 프레임: 리빌 융합 아이콘 렌더(%d px)" % reveal_icon)
	var reveal_log_gold := _scan_region_band(handoff, 200, 560, 258, 302, 0.78, 1.01, 0.52, 0.90, 0.00, 0.48)
	_check(reveal_log_gold > 15, "핸드오프 프레임: 부산물 골드 로그 렌더(%d px)" % reveal_log_gold)
	var reveal_hint := _scan_region_band(handoff, 545, 748, 662, 706, 0.70, 1.01, 0.70, 1.01, 0.70, 1.01)
	_check(reveal_hint > 12, "핸드오프 프레임: 계속 힌트 렌더(%d px)" % reveal_hint)
	var skipped: Image = captures.get("s19_skip_to_reveal") as Image
	var skipped_gauge := _scan_gauge_cyan(skipped)
	var skipped_icon := _scan_region_band(skipped, 340, 420, 120, 200, 0.18, 0.62, 0.58, 1.01, 0.48, 0.94)
	_check(skipped_gauge < 20, "즉시 스킵: 시네마틱 게이지 소멸(%d px)" % skipped_gauge)
	_check(skipped_icon > 30, "즉시 스킵: 동일 프레임 리빌 아이콘 렌더(%d px)" % skipped_icon)

	# [P1-1] 카트리지 정체성 연속(B0→B2): 좌/우 페이스 플레이트에 재료
	# 아이콘 잉크가 실재하고 좌≠우(각자 자기 아이콘)여야 한다 — B2 검사가
	# 점등 섀시에서의 도킹 유지까지 함께 증명한다. ROI는 플레이트 실측
	# frac(x 0.442/0.558, y 0.510)과 결정론적 idle 시퀀스에서 유도.
	var plate_rois := {
		"s1_host_b0_dock": [[206, 234], [526, 554]],
		"s2_host_b2_gauge_success": [[316, 344], [416, 444]],
	}
	for plate_shot: String in plate_rois.keys():
		var roi_pair: Array = plate_rois[plate_shot] as Array
		var left_roi: Array = roi_pair[0] as Array
		var right_roi: Array = roi_pair[1] as Array
		var plate_image: Image = captures.get(plate_shot) as Image
		var left_stats: Dictionary = _plate_ink_stats(plate_image, int(left_roi[0]), int(left_roi[1]), 362, 390)
		var right_stats: Dictionary = _plate_ink_stats(plate_image, int(right_roi[0]), int(right_roi[1]), 362, 390)
		_check(int(left_stats["count"]) > 25, "%s: 좌 플레이트 재료 아이콘 잉크(%d px)" % [plate_shot, int(left_stats["count"])])
		_check(int(right_stats["count"]) > 25, "%s: 우 플레이트 재료 아이콘 잉크(%d px)" % [plate_shot, int(right_stats["count"])])
		var palette_distance: float = (left_stats["mean"] as Vector3).distance_to(right_stats["mean"] as Vector3)
		_check(palette_distance > 0.10, "%s: 좌≠우 아이콘 팔레트(dist=%.3f) — 각 페이스가 자기 재료 아이콘" % [plate_shot, palette_distance])

	# [P1-2] 각성 모듈: success 동시각 베이스라인 차감 잉크가 부산물
	# 카운트(1<2<3)로 단조 증가하고, B4 초기 프레임은 완전 전개 대비
	# 절반 미만이다(즉시 배치 반증 가드 — SNAP OPEN 전개 실렌더).
	var module_baseline := _scan_module_ink(captures.get("s13_reveal_success_baseline") as Image)
	var module_ink_1: int = _scan_module_ink(captures.get("s9_deploy_count1") as Image) - module_baseline
	var module_ink_2: int = _scan_module_ink(captures.get("s10_deploy_count2") as Image) - module_baseline
	var module_ink_3: int = _scan_module_ink(captures.get("s11_deploy_count3") as Image) - module_baseline
	var module_early_baseline := _scan_module_ink(captures.get("s18_success_early_baseline") as Image)
	var module_ink_early: int = maxi(0, _scan_module_ink(captures.get("s12_deploy_early_snap") as Image) - module_early_baseline)
	_check(module_ink_1 > 60, "부산물 1개: 모듈 하드웨어 잉크 전개(%d px)" % module_ink_1)
	_check(module_ink_2 >= module_ink_1 + 60, "부산물 2개: 모듈 잉크 단조 증가(%d >= %d+60)" % [module_ink_2, module_ink_1])
	_check(module_ink_3 >= module_ink_2 + 60, "부산물 3개: 모듈 잉크 단조 증가(%d >= %d+60)" % [module_ink_3, module_ink_2])
	_check(module_ink_early * 2 < module_ink_3, "SNAP OPEN 전개: B4 초기 잉크(%d px)가 완전 전개(%d px)의 절반 미만 — 즉시 배치 아님" % [module_ink_early, module_ink_3])

	# CB4c-1: B4 코어 페이스 대각 합성 융합 아이콘 — fixture의 첫 재료 적색
	# 잉크와 둘째 재료의 밝은 저채도 잉크가 코어 중앙 ROI에 함께 실재해야 한다.
	# 배경 팔레트에 기대던 옛 녹색 탐침은 주물 에셋 교체 후 공허해져 제거한다.
	for face_shot: String in ["s6_host_b4_reveal_awakened", "s13_reveal_success_baseline"]:
		var face_image: Image = captures.get(face_shot) as Image
		var face_red := _scan_region_band(face_image, 354, 406, 349, 401, 0.55, 1.01, 0.00, 0.42, 0.00, 0.42)
		var face_neutral := _scan_neutral_band(face_image, 354, 406, 349, 401)
		_check(face_red > 25, "%s: 코어 페이스 합성 아이콘 적 팔레트(%d px)" % [face_shot, face_red])
		_check(face_neutral > 25, "%s: 코어 페이스 둘째 재료 저채도 잉크(%d px)" % [face_shot, face_neutral])
		# 상단의 첫 재료 적색이 세로 반분 경계를 넘어가면 수직 50:50 합성이
		# 아님을 증명한다. 하단에는 둘째 재료 저채도 잉크가 별도로 남아야 한다.
		var red_top_max := _band_extent_x(face_image, 354, 406, 349, 375, true, 0.55, 1.01, 0.00, 0.42, 0.00, 0.42)
		var neutral_bottom := _scan_neutral_band(face_image, 354, 406, 377, 401)
		_check(red_top_max >= 386, "%s: 대각 — 상단 적 귀속이 세로 경계 우측까지(max_x=%d >= 386)" % [face_shot, red_top_max])
		_check(neutral_bottom > 20, "%s: 대각 — 하단 둘째 재료 잉크(%d px)" % [face_shot, neutral_bottom])

	# 경사/비중첩(전면 오버레이 반증) 레그는 고알파(0.90) s13이 소유한다 —
	# s6(알파 0.72)은 우측 재료 아트의 저채도 적 디테일이 어두운 블렌드에서
	# 적 밴드로 섞여(실측 max_x=394) 아트 노이즈에 취약. 하단에서 적이
	# 후퇴해야 첫 재료가 전면을 덮는 합성이 아님을 픽셀로 반증한다.
	var tilt_image: Image = captures.get("s13_reveal_success_baseline") as Image
	var tilt_red_bottom_max := _band_extent_x(tilt_image, 354, 406, 384, 401, true, 0.55, 1.01, 0.00, 0.42, 0.00, 0.42)
	_check(tilt_red_bottom_max == -1 or tilt_red_bottom_max <= 378, "s13: 대각 — 하단 적 후퇴(max_x=%d <= 378, 전면 중첩 아님)" % tilt_red_bottom_max)

	# CB4c-2: 스파크 실렌더 — 벤트 팬(측면 해치 대역, 백열-핫 코어 밴드:
	# 골드 버클(b 0.27)·시안 룬(r 0.32)과 분리)과 골드 샤워(상부 낙하
	# 대역). 성공 s13 동일 대역=침묵(카운트 게이트의 픽셀 증명).
	var vent_image: Image = captures.get("s14_vent_sparks_side_effect") as Image
	var vent_left_ink := _scan_region_band(vent_image, 190, 310, 400, 480, 0.85, 1.01, 0.72, 1.01, 0.50, 1.01)
	var vent_right_ink := _scan_region_band(vent_image, 450, 570, 400, 480, 0.85, 1.01, 0.72, 1.01, 0.50, 1.01)
	_check(vent_left_ink > 60, "s14: 좌 벤트 스파크 팬 실렌더(%d px)" % vent_left_ink)
	_check(vent_right_ink > 60, "s14: 우 벤트 스파크 팬 실렌더(%d px)" % vent_right_ink)
	var shower_image: Image = captures.get("s15_gold_shower_byproduct") as Image
	var shower_ink := _scan_shower_band(shower_image)
	_check(shower_ink > 60, "s15: 골드 각성 스파크 샤워 실렌더(%d px)" % shower_ink)
	# CB4c-3: B3 용융/열 아지랑이 — 픽셀 봉인은 "서지 적" 밴드만 소유한다
	# (실측: haze ON 25px / OFF 7px — FAULT 서지 아크 7px만 잔존, 임계 15).
	# 기본 골드 프리셋은 이그니션 시트 아트와 동색이라 밴드 판별 불가
	# (haze OFF에서도 98px)임을 반증 실측으로 확인 — 기본 프리셋의 계약은
	# 스모크 행동 씰(B3 가시·intensity·공유 셰이더·finish 소등)+시각 검수
	# 소유. 휘도 합 차분도 6~7%라 절대 임계 부적격(실측 기록).
	var haze_surge := _scan_annulus_band(captures.get("s14_vent_sparks_side_effect") as Image, 34.0, 108.0, 0.72, 1.01, 0.18, 0.52, 0.02, 0.42)
	_check(haze_surge > 15, "s14: 서지 적 용융 쉬머 실렌더(%d px > 15 — haze OFF 실측 7px)" % haze_surge)

	# [P2-1] 스테일 재사용: 재개된 success 모달 B0 프레임에서 이전 모달의
	# 벤트 스파크가 보이면 하드 클리어 실패(수명 내 생존자 이월).
	var stale_image: Image = captures.get("s17_stale_reuse_success") as Image
	var stale_vent_left := _scan_region_band(stale_image, 190, 310, 400, 480, 0.85, 1.01, 0.72, 1.01, 0.50, 1.01)
	var stale_vent_right := _scan_region_band(stale_image, 450, 570, 400, 480, 0.85, 1.01, 0.72, 1.01, 0.50, 1.01)
	_check(stale_vent_left <= 20, "s17: 재사용 호스트 벤트 대역 클리어(좌 %d px) — 이전 모달 스파크 이월 없음" % stale_vent_left)
	_check(stale_vent_right <= 20, "s17: 재사용 호스트 벤트 대역 클리어(우 %d px)" % stale_vent_right)

	var success_b4: Image = captures.get("s13_reveal_success_baseline") as Image
	var silent_vent := _scan_region_band(success_b4, 190, 310, 400, 480, 0.85, 1.01, 0.72, 1.01, 0.50, 1.01)
	var silent_shower := _scan_shower_band(captures.get("s16_shower_silent_success") as Image)
	_check(silent_vent <= 20, "s13(성공): 벤트 대역 침묵(%d px, 정적 림 하이라이트 잔량 허용) — 카운트 게이트 픽셀 증명" % silent_vent)
	_check(shower_ink >= silent_shower + 15, "s15 부산물 샤워가 동일 타임스텝 성공 베이스라인보다 우세(%d >= %d+15)" % [shower_ink, silent_shower])

	var degraded: Image = captures.get("s0_degraded_b2_immediate") as Image
	var corner: Color = degraded.get_pixel(8, 8)
	_check(corner.v < 0.09, "백드롭 dim 적용(모서리 v=%.2f < 원배경 0.12)" % corner.v)


# 플레이트 ROI 잉크 통계: 빈 플레이트는 근흑(v≈0.14) — v>0.30 픽셀이
# 재료 아이콘 잉크다. mean 팔레트로 좌≠우 상이성을 판정한다.
func _plate_ink_stats(image: Image, x_min: int, x_max: int, y_min: int, y_max: int) -> Dictionary:
	if image == null:
		return {"count": -1, "mean": Vector3.ZERO}
	var count := 0
	var sum := Vector3.ZERO
	for y in range(y_min, y_max):
		for x in range(x_min, x_max):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.v > 0.30:
				count += 1
				sum += Vector3(pixel.r, pixel.g, pixel.b)
	return {"count": count, "mean": (sum / float(count)) if count > 0 else Vector3.ZERO}


# 밴드 픽셀의 x-극값(want_max=true면 최대, false면 최소; 부재 시 -1) —
# 대각 분할의 행별 재료 귀속 경계를 재는 전수(스트라이드 1) 스캔.
func _band_extent_x(
	image: Image,
	x_min: int,
	x_max: int,
	y_min: int,
	y_max: int,
	want_max: bool,
	r_min: float,
	r_max: float,
	g_min: float,
	g_max: float,
	b_min: float,
	b_max: float
) -> int:
	if image == null:
		return -1
	var extent := -1
	for y in range(y_min, y_max):
		for x in range(x_min, x_max):
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= r_min and pixel.r < r_max
				and pixel.g >= g_min and pixel.g < g_max
				and pixel.b >= b_min and pixel.b < b_max
			):
				if extent == -1 or (want_max and x > extent) or (not want_max and x < extent):
					extent = x
	return extent


# 중심 annulus 색 밴드 스캔(r_min~r_max) — 용융 쉬머 등 섀시 몸통 위
# additive 레이어의 잉크를 계수한다.
func _scan_annulus_band(
	image: Image,
	radius_min: float,
	radius_max: float,
	r_min: float,
	r_max: float,
	g_min: float,
	g_max: float,
	b_min: float,
	b_max: float
) -> int:
	if image == null:
		return -1
	var center := Vector2(760.0, 750.0) * 0.5
	var count := 0
	var span: int = int(radius_max) + 4
	for y in range(int(center.y) - span, int(center.y) + span, 2):
		for x in range(int(center.x) - span, int(center.x) + span, 2):
			var radius: float = Vector2(float(x), float(y)).distance_to(center)
			if radius < radius_min or radius > radius_max:
				continue
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= r_min and pixel.r < r_max
				and pixel.g >= g_min and pixel.g < g_max
				and pixel.b >= b_min and pixel.b < b_max
			):
				count += 1
	return count


# 골드 샤워 대역 스캔: 상부 낙하 대역(240~520 x 218~310)에서 웜-골드
# 스파크(b 0.42~0.80 — 백색 스펙큘러 b>=0.80 제외)를 계수하되, 정적 림
# 골드 버클 3점(좌상/정상/우상)의 웜-화이트 하이라이트 박스를 제외한다
# (s13 실측 오염 클러스터 (280,260~290)/(360~390,220~250)/(460~490,
# 255~295) — 실측 재캘리브 트랩: 에셋 바뀌면 다시 잰다).
func _scan_shower_band(image: Image) -> int:
	if image == null:
		return -1
	var count := 0
	for y in range(218, 310):
		for x in range(240, 520, 2):
			if x >= 268 and x < 302 and y >= 253 and y < 297:
				continue
			if x >= 353 and x < 397 and y >= 213 and y < 257:
				continue
			if x >= 448 and x < 497 and y >= 253 and y < 297:
				continue
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= 0.88 and pixel.g >= 0.80
				and pixel.b >= 0.42 and pixel.b < 0.80
			):
				count += 1
	return count


# B4 각성 모듈 잉크: 섀시 림 annulus(r 104~170) 안의 밝은 비-시안 픽셀
# — 시안 계열(전이 펄스 링/섀시 인레이) 제외로 모듈 하드웨어(골드/스틸)
# 만 계수한다. success 동시각 샷과의 차분이 모듈 순수 기여분.
func _scan_module_ink(image: Image) -> int:
	if image == null:
		return -1
	var center := Vector2(760.0, 750.0) * 0.5
	var count := 0
	for y in range(int(center.y) - 176, int(center.y) + 176, 2):
		for x in range(int(center.x) - 176, int(center.x) + 176, 2):
			var radius: float = Vector2(float(x), float(y)).distance_to(center)
			if radius < 104.0 or radius > 170.0:
				continue
			var pixel: Color = image.get_pixel(x, y)
			if pixel.v > 0.26 and (pixel.b - pixel.r) < 0.22:
				count += 1
	return count


func _scan_immediate_fallback_jade(image: Image) -> int:
	# 주물 의식 즉시모드 폴백의 좌측 옥빛 재료구 전용 ROI. 텍스처 호스트의
	# 단청 옥빛 장식이 같은 색대에 있어도 이 ROI에서는 폴백 원의 면적이 3배
	# 이상 크다. 중앙 코어가 아닌 좌측 재료구를 보므로 이중 드로도 분리한다.
	if image == null:
		return -1
	var count := 0
	for y in range(335, 420):
		for x in range(280, 350):
			var pixel: Color = image.get_pixel(x, y)
			if (
				pixel.r >= 0.20 and pixel.r < 0.55
				and pixel.g >= 0.60 and pixel.g < 0.98
				and pixel.b >= 0.48 and pixel.b < 0.92
			):
				count += 1
	return count


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
			if pixel.r >= 0.12 and pixel.r < 0.62 and pixel.g >= 0.55 and pixel.g < 1.01 and pixel.b >= 0.45 and pixel.b < 0.96:
				count += 1
	return count


func _count_panel_border_pixels(image: Image) -> int:
	# 주물 의식 패널의 황동-금박 테두리(상단 y≈20~45 대역 가로선).
	if image == null:
		return -1
	var count := 0
	for y in range(20, 46):
		for x in range(0, image.get_width(), 2):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r >= 0.62 and pixel.g >= 0.42 and pixel.g < 0.88 and pixel.b >= 0.08 and pixel.b < 0.52:
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


func _scan_neutral_band(image: Image, x_min: int, x_max: int, y_min: int, y_max: int) -> int:
	if image == null:
		return -1
	var count := 0
	for y in range(y_min, y_max):
		for x in range(x_min, x_max):
			var pixel: Color = image.get_pixel(x, y)
			var channel_max: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
			var channel_min: float = minf(pixel.r, minf(pixel.g, pixel.b))
			if channel_max > 0.41 and (channel_max - channel_min) / channel_max < 0.28:
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


func _byproduct_rolls_with_count(count_roll: float, selection_rolls: Array) -> Dictionary:
	var rolls := _byproduct_rolls()
	rolls["byproduct_count"] = count_roll
	rolls["byproduct_selection"] = selection_rolls
	return rolls
