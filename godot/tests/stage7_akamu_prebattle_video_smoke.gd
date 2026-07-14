extends SceneTree

# expect-zero-object-leaks — run_smoke_tests.ps1이 종료 시 ObjectDB 누수
# 경고를 이 스모크에 한해 실패로 승격한다(detached 영상 호스트/스트림 회수 봉인).

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const Stage7AkamuPrebattlePresentation := preload("res://scripts/stages/stage7/stage7_akamu_prebattle_presentation.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneReadinessController := preload("res://scripts/core/battle_scene_readiness_controller.gd")
const BattleBootWarmupController := preload("res://scripts/core/battle_boot_warmup_controller.gd")
const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const BattleSceneFlowController := preload("res://scripts/core/battle_scene_flow_controller.gd")

const VIDEO_PATH := "res://assets/video/stage7_akamu_intro_v1.ogv"
const MANIFEST_PATH := "res://assets/video/stage7_akamu_intro_v1_manifest.json"
const EXPECTED_VIDEO_BYTES := 2183964
const EXPECTED_VIDEO_SHA256 := "c44aadcd843bcf7b42445e8770e855a8b5bd2fad7277308a80c6e8fe38356982"
const EXPECTED_VIDEO_DURATION_SECONDS := 10.1
const NATURAL_END_MIN_SECONDS := 9.65
const NATURAL_END_MAX_SECONDS := 11.25

var _failures: Array[String] = []
var _qa_run_dir := ""


class OwnerProbe:
	extends Node2D

	var current_stage := 7


class AudioProbe:
	extends RefCounted

	var stop_calls := 0
	var muted := false
	var played_stages: Array[int] = []

	func stop_bgm() -> void:
		stop_calls += 1

	func is_bgm_muted() -> bool:
		return muted

	func play_stage_bgm(stage_id: int) -> bool:
		played_stages.append(stage_id)
		return true


class RegistryProbe:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


class ShellLikeGetterProbe:
	extends RefCounted

	# 실제 배틀 셸 형태: 생성형 _get_module + 캐시 peek _get_cached_module.
	var created_keys: Array[String] = []
	var cached_instances: Dictionary = {}

	func _get_module(key: String) -> Object:
		created_keys.append(key)
		var value: Variant = cached_instances.get(key, null)
		return value as Object if value is Object else null

	func _get_cached_module(key: String) -> Object:
		var value: Variant = cached_instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _is_headless_runtime():
		await _prepare_windowed_runtime()
	_verify_runtime_asset_contract()
	await _verify_presentation_lifecycle_and_clip()
	_verify_boot_gate_and_transition_order()
	_verify_wiring_and_omission_contract()
	# Let queued host frees and the threaded VideoStream loader retire before
	# SceneTree shutdown; otherwise fast headless runs can report a false leak.
	for _frame in range(12):
		await process_frame
	await create_timer(0.05).timeout
	_finalize_qa_evidence()
	if _failures.is_empty():
		print("stage7_akamu_prebattle_video_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _finalize_qa_evidence() -> void:
	# 증적 자립성: 판정 결과와 실패 목록까지 QA 디렉터리에 남긴다.
	# 기록 실패는 스모크 실패로 승격한다(판정 직전에 호출되므로 반영됨).
	if _qa_run_dir == "":
		return
	var result_file := FileAccess.open("%s/metrics.txt" % _qa_run_dir, FileAccess.READ_WRITE)
	if result_file == null:
		_failures.append("windowed QA evidence must record the final verdict (metrics.txt reopen failed)")
		return
	result_file.seek_end()
	result_file.store_line("result=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	for failure in _failures:
		result_file.store_line("failure=%s" % failure)
	result_file.close()


func _describe_git_state() -> String:
	# 정확한 워크트리 '내용' 귀속: HEAD + tracked 변경은 `git diff HEAD`
	# 출력의 sha256(경로+상태만 담는 porcelain과 달리 바이트 차이를 식별),
	# untracked는 파일별 내용 sha256을 정렬해 함께 해시. git 실패는
	# unavailable로 표기(성공처럼 위장하지 않음).
	var repo_dir := ProjectSettings.globalize_path("res://").rstrip("/").get_base_dir()
	var head_output: Array = []
	if OS.execute("git", ["-C", repo_dir, "rev-parse", "HEAD"], head_output) != 0:
		return "unavailable"
	var status_output: Array = []
	if OS.execute("git", ["-C", repo_dir, "status", "--porcelain", "--untracked-files=normal"], status_output) != 0:
		return "unavailable(status_failed)"
	var porcelain := str(status_output[0]) if status_output.size() > 0 else ""
	var dirty_lines := 0
	for line in porcelain.split("\n"):
		if line.strip_edges() != "":
			dirty_lines += 1
	var diff_output: Array = []
	if OS.execute("git", ["-C", repo_dir, "diff", "HEAD"], diff_output) != 0:
		return "unavailable(diff_failed)"
	var tracked_content_sha := (str(diff_output[0]) if diff_output.size() > 0 else "").sha256_text()
	var untracked_output: Array = []
	if OS.execute("git", ["-C", repo_dir, "ls-files", "--others", "--exclude-standard"], untracked_output) != 0:
		return "unavailable(untracked_failed)"
	var untracked_records: Array[String] = []
	for untracked_line in (str(untracked_output[0]) if untracked_output.size() > 0 else "").split("\n"):
		var untracked_path := untracked_line.strip_edges()
		if untracked_path == "":
			continue
		var absolute_path := "%s/%s" % [repo_dir, untracked_path]
		var content_sha := FileAccess.get_sha256(absolute_path)
		untracked_records.append("%s:%s" % [untracked_path, content_sha])
	untracked_records.sort()
	var untracked_content_sha := "\n".join(untracked_records).sha256_text()
	return "%s dirty_entries=%d tracked_diff_sha256=%s untracked_manifest_sha256=%s untracked_files=%d" % [
		str(head_output[0]).strip_edges() if head_output.size() > 0 else "?",
		dirty_lines,
		tracked_content_sha,
		untracked_content_sha,
		untracked_records.size(),
	]


func _verify_runtime_asset_contract() -> void:
	_expect(FileAccess.file_exists(VIDEO_PATH), "tracked Stage 7 OGV should exist")
	var file := FileAccess.open(VIDEO_PATH, FileAccess.READ)
	_expect(file != null, "Stage 7 OGV should be readable")
	if file != null:
		_expect(file.get_length() == EXPECTED_VIDEO_BYTES, "Stage 7 OGV byte size should match the provenance manifest")
		var magic := file.get_buffer(4).get_string_from_ascii()
		_expect(magic == "OggS", "Stage 7 cinematic should use an Ogg container, not the ignored MP4")
	_expect(FileAccess.get_sha256(VIDEO_PATH).to_lower() == EXPECTED_VIDEO_SHA256, "Stage 7 OGV bytes should match the decode-validated SHA-256")
	var video_resource: Resource = ResourceLoader.load(VIDEO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(video_resource is VideoStream, "Stage 7 OGV should import as a Godot VideoStream")

	_expect(FileAccess.file_exists(MANIFEST_PATH), "Stage 7 video provenance manifest should exist")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "Stage 7 video provenance manifest should parse")
	if parsed is Dictionary:
		var manifest := parsed as Dictionary
		var runtime: Dictionary = manifest.get("runtime", {})
		var transform: Dictionary = manifest.get("offline_transform", {})
		var policy: Dictionary = manifest.get("runtime_policy", {})
		_expect(str(runtime.get("sha256", "")) == EXPECTED_VIDEO_SHA256, "manifest should seal the runtime OGV hash")
		_expect(int(runtime.get("bytes", 0)) == EXPECTED_VIDEO_BYTES, "manifest should seal the runtime OGV byte size")
		_expect(runtime.get("video", "") == "theora 760x750 30fps", "runtime video should be pre-padded to the full 760x750 playfield")
		_expect(runtime.get("coded_frame", "") == "768x752" and int(runtime.get("decoded_video_frames", 0)) == 300, "manifest should seal Theora coded bounds and all 300 frames")
		_expect(runtime.get("audio", "") == "vorbis stereo 48000Hz", "runtime audio should use Godot-compatible 48 kHz stereo Vorbis")
		_expect(is_equal_approx(float(runtime.get("duration_seconds", 0.0)), EXPECTED_VIDEO_DURATION_SECONDS), "manifest should seal the 10.1 second runtime duration")
		_expect(transform.get("aspect_policy", "") == "contain", "portrait source should use contain rather than legacy distortion")
		_expect(str(transform.get("decode_validation", "")).find("-xerror full-stream pass") >= 0, "manifest should record the full-stream decode gate")
		_expect(policy.get("jrpg_dialogue", "") == "intentionally_omitted_for_godot_port", "port policy should explicitly omit the JRPG dialogue")


func _verify_presentation_lifecycle_and_clip() -> void:
	var owner := OwnerProbe.new()
	root.add_child(owner)
	var audio := AudioProbe.new()
	var layout := BattleViewLayout.new()
	var registry := RegistryProbe.new()
	registry.instances = {
		"game_audio": audio,
		"battle_view_layout": layout,
	}
	var retry_probe := Stage7AkamuPrebattlePresentation.new()
	retry_probe.reset_for_stage_entry(7)
	retry_probe.set("_video_load_failed", true)
	retry_probe.set("_missing_warning_emitted", true)
	for _attempt in range(3):
		_expect(bool(retry_probe.prewarm_assets_step()), "a failed video load should stay terminal within the current entry")
	_expect(bool(retry_probe.get_asset_status().get("video_load_failed", false)), "same-entry prewarm calls must not clear the failure latch")
	_expect(not bool(retry_probe.get("_video_load_requested")), "same-entry failure must not create a threaded retry storm")
	retry_probe.reset_for_stage_entry(7)
	_expect(bool(retry_probe.get_asset_status().get("video_load_failed", false)), "entry arming after a failed prewarm must preserve this-entry degradation")
	_expect(not retry_probe.begin_video(owner, registry), "the failed current entry should degrade directly to the normal landing flow")
	_expect(retry_probe.get_completion_reason() == "load_failed", "current-entry degradation should record the load-failed completion reason")
	_expect(not bool(retry_probe.get("_video_load_requested")), "degrading the current entry must not start a second request")
	retry_probe.reset()
	_expect(not bool(retry_probe.get_asset_status().get("video_load_failed", true)), "a later match reset should clear the prior entry's transient video-load failure")
	_expect(not bool(retry_probe.get("_missing_warning_emitted")), "a later match reset should re-arm one warning for a fresh retry")
	_expect(not bool(retry_probe.get("_video_load_requested")), "reset should clear the retry policy without starting I/O itself")
	retry_probe.reset()
	_expect(not bool(retry_probe.get("_video_load_requested")), "repeated reset calls must remain I/O-free")
	retry_probe.tear_down()
	retry_probe = null
	var presentation := Stage7AkamuPrebattlePresentation.new()
	var timeout_probe := Stage7AkamuPrebattlePresentation.new()
	timeout_probe.set("_video_load_requested", true)
	timeout_probe.set("_video_load_started_msec", Time.get_ticks_msec())
	timeout_probe.set("_video_load_poll_count", 600)
	_expect(bool(timeout_probe.call("_is_video_thread_load_expired")), "threaded video prewarm should have a hard poll-count escape hatch")
	timeout_probe = null
	# Fast headless processes seed the validated stream to avoid Godot's flaky
	# exit-time threaded-worker warning. Windowed QA deliberately exercises the
	# real production threaded request and then keeps the process alive for the
	# complete 10.1 second playback.
	var seeded_video: VideoStream = null
	if _is_headless_runtime():
		seeded_video = ResourceLoader.load(VIDEO_PATH) as VideoStream
		_expect(seeded_video != null, "headless lifecycle smoke should seed the validated VideoStream")
		presentation.set("_video_stream", seeded_video)

	var prewarm_done := false
	for _frame in range(240):
		prewarm_done = bool(presentation.prewarm_stage_entry_step(owner))
		if prewarm_done:
			break
		await process_frame
	_expect(prewarm_done, "Stage 7 video and detached host should finish staged prewarm")
	var asset_status: Dictionary = presentation.get_asset_status()
	_expect(bool(asset_status.get("video_loaded", false)), "Stage 7 prewarm should retain the VideoStream")
	_expect(bool(asset_status.get("host_ready", false)), "Stage 7 prewarm should create the hidden host before first display")
	var prewarmed_host: Control = presentation.get_host_for_test()
	_expect(prewarmed_host != null and not prewarmed_host.visible, "prewarmed host should remain hidden")
	_expect(prewarmed_host != null and not prewarmed_host.is_processing(), "prewarmed host should not own an idle process loop")

	presentation.reset_for_stage_entry(7)
	_expect(presentation.blocks_battle_physics(), "a fresh Stage 7 entry should block physics until its video completes")
	_expect(presentation.begin_video(owner, registry), "fresh Stage 7 entry should begin the cinematic")
	_expect(presentation.get_phase() == "video", "presentation should enter the video phase")
	_expect(audio.stop_calls == 1, "embedded video audio should replace the already-primed stage BGM")

	var host: Control = presentation.get_host_for_test()
	var snapshot: Dictionary = host.get_clip_snapshot() if host != null else {}
	var view_size := owner.get_viewport_rect().size
	var expected_layout: Dictionary = layout.build_game_layout(view_size, 760.0, 750.0)
	_expect(bool(snapshot.get("host_visible", false)), "video host should be visible during playback")
	_expect(not bool(snapshot.get("host_process_enabled", true)), "controller-driven video host should keep its own process disabled")
	_expect(bool(snapshot.get("clip_contents", false)), "video host should clip its children")
	_expect(int(snapshot.get("clip_children", -1)) == CanvasItem.CLIP_CHILDREN_AND_DRAW, "video host should use the strict children-and-draw clip mode")
	_expect(bool(snapshot.get("video_parent_is_clip", false)), "VideoStreamPlayer should remain a direct child of the playfield clip")
	_expect(snapshot.get("clip_position", Vector2.ZERO) == expected_layout.get("game_offset", Vector2.ZERO), "video clip should begin at the exact game-canvas offset")
	_expect(snapshot.get("clip_size", Vector2.ZERO) == expected_layout.get("game_size", Vector2.ZERO), "video clip should match the full scaled 760x750 game canvas")
	_expect(snapshot.get("video_position", Vector2.ONE) == Vector2.ZERO, "pre-padded video should start at local playfield origin")
	_expect(snapshot.get("video_size", Vector2.ZERO) == snapshot.get("clip_size", Vector2.ONE), "pre-padded video should fill only the clipped playfield")
	if not _is_headless_runtime():
		audio.muted = true
		var playback_started_msec := Time.get_ticks_msec()
		await _verify_windowed_video_frame(presentation, owner, registry, expected_layout, playback_started_msec)
		_expect(presentation.was_video_completed_for_entry(), "windowed playback should reach the VideoStream finished signal without the duration fallback")
		_expect(presentation.get_completion_reason() == "natural", "windowed playback should finish from VideoStreamPlayer.finished rather than the duration fallback")
		presentation.reset_for_stage_entry(7)
		_expect(presentation.begin_video(owner, registry), "windowed natural-end verification should re-arm a fresh entry for skip coverage")

	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_SPACE
	audio.muted = false
	# 코덱스 P1 봉인: 스킵은 presentation.handle_input 직접 호출이 아니라
	# 실제 셸 입력 컨트롤러를 경유해야 한다 — 프리배틀 라우터가 intro/warmup
	# 차단 조기 반환(랜딩 시작 전 = 항상 true)보다 뒤에 있으면 여기서 RED.
	registry.instances["stage7_akamu_prebattle_presentation"] = presentation
	registry.instances["battle_scene_readiness_controller"] = BattleSceneReadinessController.new()
	var shell_input: Object = BattleSceneInputController.new()
	shell_input.handle_unhandled_input(skip, owner, registry, Callable(registry, "get_instance"), {
		"battle_initialized": true,
		"stage_landing_intro_started": false,
	})
	_expect(presentation.get_phase() == "fade", "real shell input routing should reach the Stage 7 video skip before the intro/warmup early return")
	_expect(presentation.get_completion_reason() == "skip", "manual input should record the skip completion path")
	snapshot = host.get_clip_snapshot()
	_expect(host.visible and bool(snapshot.get("video_playing", false)), "skip fade should retain the current video frame and embedded audio until fade completion")
	presentation.update(0.25, owner, registry)
	snapshot = host.get_clip_snapshot()
	var faded_volume_db := float(snapshot.get("video_volume_db", 0.0))
	_expect(faded_volume_db <= -5.0 and faded_volume_db > -79.0, "skip fade should attenuate embedded audio instead of cutting it abruptly")
	presentation.update(0.26, owner, registry)
	_expect(presentation.was_video_completed_for_entry(), "fade completion should seal the one-shot entry state")
	_expect(not presentation.is_active(), "presentation should release the intro frame after fade")
	_expect(not presentation.blocks_battle_physics(), "video completion should release battle physics")
	_expect(not host.visible and not bool(host.get_clip_snapshot().get("video_playing", true)), "video host and embedded audio should stop on completion")
	_expect(not presentation.begin_video(owner, registry), "same Stage 7 entry should never replay the video")

	audio.muted = true
	presentation.reset_for_stage_entry(7)
	_expect(presentation.begin_video(owner, registry), "new Stage 7 entry should re-arm the cinematic")
	snapshot = host.get_clip_snapshot()
	_expect(float(snapshot.get("video_volume_db", 0.0)) <= -79.0, "BGM mute state should also mute embedded cinematic audio")
	var touch_skip := InputEventScreenTouch.new()
	touch_skip.pressed = true
	_expect(presentation.handle_input(touch_skip, owner, registry), "mobile screen touch should skip the cinematic while battle controls are gated")
	presentation.update(0.51, owner, registry)

	# 코덱스 P2 봉인: 스킵 입력 계약을 Space 한 종류에 묶지 않는다 — Enter,
	# 좌클릭, 게임패드 A, 터치 전부 '실제 셸 입력 컨트롤러' 경유로 도달.
	audio.muted = false
	var enter_skip := InputEventKey.new()
	enter_skip.pressed = true
	enter_skip.keycode = KEY_ENTER
	var mouse_skip := InputEventMouseButton.new()
	mouse_skip.pressed = true
	mouse_skip.button_index = MOUSE_BUTTON_LEFT
	var joy_skip := InputEventJoypadButton.new()
	joy_skip.pressed = true
	joy_skip.button_index = JOY_BUTTON_A
	var touch_skip_shell := InputEventScreenTouch.new()
	touch_skip_shell.pressed = true
	var skip_matrix := {
		"enter": enter_skip,
		"mouse_left": mouse_skip,
		"gamepad_a": joy_skip,
		"screen_touch": touch_skip_shell,
	}
	for skip_label in skip_matrix:
		presentation.reset_for_stage_entry(7)
		_expect(presentation.begin_video(owner, registry), "skip matrix (%s) should re-arm a fresh entry" % skip_label)
		shell_input.handle_unhandled_input(skip_matrix[skip_label], owner, registry, Callable(registry, "get_instance"), {
			"battle_initialized": true,
			"stage_landing_intro_started": false,
		})
		_expect(
			presentation.get_phase() == "fade",
			"real shell input routing should skip the cinematic via %s" % skip_label
		)
		presentation.update(0.51, owner, registry)
	presentation.reset_for_stage_entry(7)
	_expect(presentation.begin_video(owner, registry), "result cleanup coverage should begin from a live video")
	presentation.reset_for_result()
	_expect(not host.visible and not bool(host.get_clip_snapshot().get("video_playing", true)), "result cleanup should stop and hide a mid-video host")

	owner.current_stage = 6
	presentation.reset_for_stage_entry(6)
	_expect(not presentation.begin_video(owner, registry), "non-Stage 7 entries should bypass the cinematic")
	presentation.tear_down()
	presentation.set("_video_stream", null)
	seeded_video = null
	await process_frame
	host = null
	prewarmed_host = null
	registry.instances.clear()
	presentation = null
	audio = null
	layout = null
	registry = null
	if is_instance_valid(owner):
		owner.free()
	owner = null
	await process_frame


func _verify_boot_gate_and_transition_order() -> void:
	# 코덱스 P1 봉인 1: in-flight 스레드 영상 로드는 부트 웜업의 frame-gated
	# 계약에 등재돼야 한다 — 아니면 budgeted 루프가 같은 스텝을 프레임당
	# 최대 128회 폴링해 600-poll 탈출구가 냉부트 ~5프레임 만에 소진된다.
	var inflight_probe := Stage7AkamuPrebattlePresentation.new()
	inflight_probe.set("_video_load_requested", true)
	_expect(bool(inflight_probe.is_video_thread_load_in_flight()), "requested-but-unloaded video should report in-flight")
	var warmup_registry := RegistryProbe.new()
	warmup_registry.instances = {"stage7_akamu_prebattle_presentation": inflight_probe}
	var warmup: Object = BattleBootWarmupController.new()
	_expect(
		bool(warmup._is_waiting_on_frame_gated_work(null, Callable(warmup_registry, "get_instance"))),
		"boot warmup budget loop must treat the in-flight video load as frame-gated work"
	)
	inflight_probe.set("_video_load_requested", false)
	_expect(
		not bool(warmup._is_waiting_on_frame_gated_work(null, Callable(warmup_registry, "get_instance"))),
		"an idle presentation must not hold the boot warmup gate open"
	)
	# 코덱스 P2 봉인: 실제 셸 형태(생성형 _get_module + 캐시 peek
	# _get_cached_module)에서 프리배틀 키는 '생성형 getter로 조회되면 안
	# 된다' — 타 스테이지 부트가 Stage 7 presentation을 생성하는 회귀 방지.
	var shell_getter := ShellLikeGetterProbe.new()
	warmup._is_waiting_on_frame_gated_work(null, Callable(shell_getter, "_get_module"))
	_expect(
		not shell_getter.created_keys.has("stage7_akamu_prebattle_presentation"),
		"boot gate must peek the prebattle key through _get_cached_module, never the creating shell getter"
	)
	shell_getter.cached_instances["stage7_akamu_prebattle_presentation"] = inflight_probe
	inflight_probe.set("_video_load_requested", true)
	_expect(
		bool(warmup._is_waiting_on_frame_gated_work(null, Callable(shell_getter, "_get_module"))),
		"a cached in-flight presentation must still hold the gate through the shell-shaped peek"
	)
	inflight_probe.set("_video_load_requested", false)
	inflight_probe = null

	# 코덱스 P1 봉인 2: 스테이지 6→7 전환의 워크스텝 9는 BGM을 선재생하면
	# 안 된다(선재생→영상 시작 시 단절→영상음→재시작 왕복). 비-7 스테이지는
	# 기존대로 스텝 9에서 재생한다.
	var transition_owner := OwnerProbe.new()
	root.add_child(transition_owner)
	var stage7_audio := AudioProbe.new()
	var stage7_registry := RegistryProbe.new()
	stage7_registry.instances = {"game_audio": stage7_audio}
	var stage7_driver: Object = BattleSceneMatchEventDriver.new()
	stage7_driver.set("_stage_transition_loading_work_step", 9)
	stage7_driver._run_stage_transition_loading_work_step(transition_owner, stage7_registry, 7)
	_expect(stage7_audio.played_stages.is_empty(), "stage 6->7 transition step 9 must defer BGM to the post-video landing path")
	var stage6_audio := AudioProbe.new()
	var stage6_registry := RegistryProbe.new()
	stage6_registry.instances = {"game_audio": stage6_audio}
	var stage6_driver: Object = BattleSceneMatchEventDriver.new()
	stage6_driver.set("_stage_transition_loading_work_step", 9)
	stage6_driver._run_stage_transition_loading_work_step(transition_owner, stage6_registry, 6)
	_expect(stage6_audio.played_stages == [6], "non-stage-7 transitions should keep the step-9 BGM start")
	transition_owner.free()

	# 코덱스 P2 봉인: 실제 6→7 전환 연속 경로 — step 9 무재생 → 전환 완료
	# replay(전체 인트로 재무장, BGM 래치 해제) → 영상 재생 중 무재생 →
	# 영상 종료 후 랜딩 재진입에서 BGM 정확히 1회.
	var chain_owner := OwnerProbe.new()
	chain_owner.current_stage = 6
	root.add_child(chain_owner)
	var chain_audio := AudioProbe.new()
	var chain_flow: Object = BattleSceneFlowController.new()
	chain_flow.set("_battle_initialized", true)
	chain_flow.set("_battle_bgm_started", true)
	var chain_presentation: Object = Stage7AkamuPrebattlePresentation.new()
	chain_presentation.set("_video_stream", ResourceLoader.load(VIDEO_PATH))
	var chain_registry := RegistryProbe.new()
	chain_registry.instances = {
		"game_audio": chain_audio,
		"battle_view_layout": BattleViewLayout.new(),
		"battle_scene_flow_controller": chain_flow,
		"stage7_akamu_prebattle_presentation": chain_presentation,
	}
	var chain_driver: Object = BattleSceneMatchEventDriver.new()
	chain_driver.set("_stage_transition_loading_work_step", 9)
	chain_driver._run_stage_transition_loading_work_step(chain_owner, chain_registry, 7)
	_expect(chain_audio.played_stages.is_empty(), "chained 6->7 step 9 must not pre-play stage 7 BGM")
	chain_driver._replay_ball_spawn_intro_for_stage_transition(chain_owner, chain_registry)
	_expect(chain_presentation.get_phase() == "video", "transition replay should re-arm and start the cinematic")
	_expect(chain_audio.played_stages.is_empty(), "BGM must stay deferred while the transition cinematic plays")
	var chain_skip := InputEventKey.new()
	chain_skip.pressed = true
	chain_skip.keycode = KEY_SPACE
	chain_presentation.handle_input(chain_skip, chain_owner, chain_registry)
	chain_presentation.update(0.51, chain_owner, chain_registry)
	chain_flow.begin_stage_landing_intro(
		chain_owner,
		chain_registry,
		Callable(chain_registry, "get_instance"),
		Callable(chain_registry, "get_instance")
	)
	_expect(chain_audio.played_stages == [7], "post-video landing re-entry should start stage 7 BGM exactly once")
	chain_presentation.reset_for_result()
	chain_presentation.tear_down()
	chain_presentation.set("_video_stream", null)

	# 로드 실패 degradation 연속 경로: 전환 replay가 실패 래치 상태의 영상을
	# 만나면 즉시 정상 랜딩으로 진행하고 BGM도 1회 시작해야 한다(무음 금지).
	var degraded_owner := OwnerProbe.new()
	degraded_owner.current_stage = 6
	root.add_child(degraded_owner)
	var degraded_audio := AudioProbe.new()
	var degraded_flow: Object = BattleSceneFlowController.new()
	degraded_flow.set("_battle_initialized", true)
	degraded_flow.set("_battle_bgm_started", true)
	var degraded_presentation: Object = Stage7AkamuPrebattlePresentation.new()
	degraded_presentation.set("_video_load_failed", true)
	degraded_presentation.set("_missing_warning_emitted", true)
	var degraded_registry := RegistryProbe.new()
	degraded_registry.instances = {
		"game_audio": degraded_audio,
		"battle_scene_flow_controller": degraded_flow,
		"stage7_akamu_prebattle_presentation": degraded_presentation,
	}
	var degraded_driver: Object = BattleSceneMatchEventDriver.new()
	degraded_driver.set("_stage_transition_loading_work_step", 9)
	degraded_driver._run_stage_transition_loading_work_step(degraded_owner, degraded_registry, 7)
	degraded_driver._replay_ball_spawn_intro_for_stage_transition(degraded_owner, degraded_registry)
	_expect(
		degraded_flow.is_stage_landing_intro_started(),
		"load-failed degradation should continue straight into the landing flow"
	)
	_expect(degraded_audio.played_stages == [7], "load-failed degradation must still start stage 7 BGM exactly once (no silent battle)")
	degraded_presentation.tear_down()
	chain_owner.free()
	degraded_owner.free()


func _verify_wiring_and_omission_contract() -> void:
	var catalog := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	var lifecycle := FileAccess.get_file_as_string("res://scripts/core/battle_scene_stage_intro_flow_lifecycle.gd")
	var frame := FileAccess.get_file_as_string("res://scripts/core/battle_scene_intro_frame_controller.gd")
	var input := FileAccess.get_file_as_string("res://scripts/core/battle_scene_intro_input_controller.gd")
	var readiness := FileAccess.get_file_as_string("res://scripts/core/battle_scene_readiness_controller.gd")
	var modal := FileAccess.get_file_as_string("res://scripts/core/battle_scene_modal_gate_controller.gd")
	var transition := FileAccess.get_file_as_string("res://scripts/core/battle_scene_match_event_driver.gd")
	var prewarm := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var reset := FileAccess.get_file_as_string("res://scripts/core/match_reset_controller.gd")
	var result := FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_runtime_context_data.gd")
	var teardown := FileAccess.get_file_as_string("res://scripts/core/battle_scene_teardown_lifecycle.gd")
	var presentation := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_prebattle_presentation.gd")
	var host := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_prebattle_overlay_host.gd")

	_expect(catalog.find("stage7_akamu_prebattle_presentation") >= 0, "stage module catalog should register the Stage 7 prebattle owner")
	_expect(lifecycle.find("stage7_akamu_prebattle_presentation") < lifecycle.find("start_battle_bgm(flow"), "video gate should run before the landing BGM start")
	_expect(frame.find("stage7_akamu_video_update") >= 0 and input.find("stage7_akamu_prebattle_presentation") >= 0, "intro frame and input owners should drive the video")
	_expect(readiness.find("is_stage7_prebattle_pending") >= 0 and modal.find("physics.modal_gate.stage7_akamu_prebattle") >= 0, "video should gate mobile readiness and physics")
	_expect(transition.find("flow.begin_stage_landing_intro") >= 0 and transition.find("stage_id == 7") >= 0, "Stage 6 to 7 transition should replay the full intro chain, not only ball spawn")
	_expect(prewarm.find("prewarm_stage_entry_step(owner)") >= 0, "Stage 7 staged prewarm should include the VideoStream and hidden host")
	_expect(presentation.find("ResourceLoader.load_threaded_request") >= 0 and presentation.find("ResourceLoader.load_threaded_get") >= 0, "production video prewarm should remain threaded")
	_expect(presentation.find("ResourceLoader.load(VIDEO_PATH)") < 0 and presentation.find("_load_video_sync_fallback") < 0, "threaded loader errors should degrade this entry instead of synchronously decoding on the main thread")
	_expect(reset.find("stage7_akamu_prebattle_presentation") >= 0 and result.find("reset_for_result") >= 0 and teardown.find("stage7_akamu_prebattle_presentation") >= 0, "reset, result, and teardown paths should explicitly clean the detached host")
	_expect(presentation.find("dialogue") < 0 and host.find("dialogue") < 0, "Godot port should not carry JRPG dialogue state or rendering")
	_expect(not FileAccess.file_exists("res://assets/sprites/bosses/stage7_akamu/stage7_akamu_dialogue_portrait_normal.png"), "omitted dialogue should not promote the normal portrait")
	_expect(not FileAccess.file_exists("res://assets/sprites/bosses/stage7_akamu/stage7_akamu_dialogue_portrait_angry.png"), "omitted dialogue should not promote the angry portrait")


func _verify_windowed_video_frame(
	presentation: Object,
	owner: Object,
	registry: Object,
	layout: Dictionary,
	playback_started_msec: int
) -> void:
	var previous_msec := playback_started_msec
	for _frame in range(36):
		await process_frame
		var now_msec := Time.get_ticks_msec()
		presentation.update(maxf(0.0, float(now_msec - previous_msec) / 1000.0), owner, registry)
		previous_msec = now_msec
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "windowed Stage 7 video should produce a viewport frame")
	if image == null or image.is_empty():
		return
	var viewport_size := root.get_visible_rect().size
	var image_scale := Vector2(
		float(image.get_width()) / maxf(1.0, viewport_size.x),
		float(image.get_height()) / maxf(1.0, viewport_size.y)
	)
	var game_offset: Vector2 = layout.get("game_offset", Vector2.ZERO)
	var game_size: Vector2 = layout.get("game_size", Vector2(760.0, 750.0))
	var lit_samples := 0
	for y_ratio in [0.18, 0.32, 0.50, 0.68, 0.82]:
		for x_ratio in [0.30, 0.50, 0.70]:
			var sample_pos := game_offset + Vector2(game_size.x * float(x_ratio), game_size.y * float(y_ratio))
			var pixel := image.get_pixelv(_to_image_position(sample_pos, image_scale, image.get_size()))
			if pixel.r + pixel.g + pixel.b > 0.16:
				lit_samples += 1
	_expect(lit_samples >= 3, "windowed OGV decode should produce visible pixels inside the playfield clip")
	var max_outside_rgb := _get_outside_band_max_rgb(image, game_offset, game_size, image_scale)
	_expect(max_outside_rgb < 0.08, "cinematic animation should stay black across every available band outside the playfield clip")
	# 실행(타임스탬프+usec)별 디렉터리에 PNG + 메트릭 + '실측' 해시 + git
	# 상태를 함께 보존한다 — 고정 파일명 덮어쓰기 금지, 병렬 동일 해상도
	# 실행 충돌 방지, 증적 자립성(코덱스 P2).
	var qa_run_dir := "user://stage7_akamu_prebattle_qa/%s_%d_%dx%d" % [
		Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_").replace("T", "_"),
		Time.get_ticks_usec(),
		image.get_width(),
		image.get_height(),
	]
	_qa_run_dir = qa_run_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_run_dir))
	var capture_path := "%s/frame.png" % qa_run_dir
	var save_error := image.save_png(capture_path)
	_expect(save_error == OK, "windowed Stage 7 video QA frame should save")
	if save_error == OK:
		print("stage7_akamu_prebattle_video_windowed_capture: %s" % ProjectSettings.globalize_path(capture_path))
	var metrics_file := FileAccess.open("%s/metrics.txt" % qa_run_dir, FileAccess.WRITE)
	_expect(metrics_file != null, "windowed QA metrics file must be writable (evidence self-containment)")
	if metrics_file != null:
		metrics_file.store_line("video_sha256_measured=%s" % FileAccess.get_sha256(VIDEO_PATH).to_lower())
		metrics_file.store_line("video_sha256_expected=%s" % EXPECTED_VIDEO_SHA256)
		metrics_file.store_line("git=%s" % _describe_git_state())
		metrics_file.store_line("viewport=%s image=%s scale=%s" % [viewport_size, image.get_size(), image_scale])
		metrics_file.store_line("lit_samples=%d max_outside_rgb=%.4f" % [lit_samples, max_outside_rgb])
		metrics_file.close()

	var signature_targets_msec := [2500, 5000, 9000]
	var frame_signatures: Array[Array] = []
	var signature_index := 0
	var natural_end_reached: bool = str(presentation.get_phase()) == "fade"
	var deadline_msec := playback_started_msec + int(ceil(NATURAL_END_MAX_SECONDS * 1000.0))
	while not natural_end_reached and Time.get_ticks_msec() <= deadline_msec:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		presentation.update(maxf(0.0, float(now_msec - previous_msec) / 1000.0), owner, registry)
		previous_msec = now_msec
		var elapsed_msec := now_msec - playback_started_msec
		if signature_index < signature_targets_msec.size() and elapsed_msec >= int(signature_targets_msec[signature_index]):
			await RenderingServer.frame_post_draw
			var signature_image := root.get_texture().get_image()
			if signature_image != null and not signature_image.is_empty():
				var signature_scale := Vector2(
					float(signature_image.get_width()) / maxf(1.0, viewport_size.x),
					float(signature_image.get_height()) / maxf(1.0, viewport_size.y)
				)
				frame_signatures.append(_build_video_frame_signature(signature_image, game_offset, game_size, signature_scale))
			signature_index += 1
		if presentation.get_phase() == "fade":
			natural_end_reached = true
	_expect(natural_end_reached, "windowed OGV playback should emit finished naturally")
	var natural_end_seconds := float(Time.get_ticks_msec() - playback_started_msec) / 1000.0
	_expect(natural_end_seconds >= NATURAL_END_MIN_SECONDS, "windowed OGV should not emit finished before its sealed 10.1 second duration")
	_expect(natural_end_seconds <= NATURAL_END_MAX_SECONDS, "windowed OGV should finish within the bounded 10.1 second playback window")
	_expect(frame_signatures.size() == signature_targets_msec.size(), "windowed decoder should expose 2.5 s, 5 s, and 9 s video frames")
	if frame_signatures.size() == signature_targets_msec.size():
		_expect(_signature_distance(frame_signatures[0], frame_signatures[1]) >= 180, "windowed decoder should advance between the 2.5 s and 5 s frames")
		_expect(_signature_distance(frame_signatures[1], frame_signatures[2]) >= 180, "windowed decoder should advance between the 5 s and 9 s frames")
	print(
		"stage7_akamu_prebattle_video_windowed_metrics: logical=%s image=%s scale=%s max_outside_rgb=%.4f natural_end=%.3fs"
		% [viewport_size, image.get_size(), image_scale, max_outside_rgb, natural_end_seconds]
	)
	var metrics_append := FileAccess.open("%s/metrics.txt" % qa_run_dir, FileAccess.READ_WRITE)
	_expect(metrics_append != null, "windowed QA metrics file must accept the natural-end record")
	if metrics_append != null:
		metrics_append.seek_end()
		metrics_append.store_line("natural_end_seconds=%.3f" % natural_end_seconds)
		metrics_append.store_line("frame_signatures=%d" % frame_signatures.size())
		for signature_record_index in range(frame_signatures.size()):
			metrics_append.store_line("frame_signature_hash_%d=%d" % [signature_record_index, hash(str(frame_signatures[signature_record_index]))])
		metrics_append.close()
	if natural_end_reached:
		presentation.update(0.51, owner, registry)


func _prepare_windowed_runtime() -> void:
	var requested_size := Vector2i(
		_get_user_arg_int("--qa-width=", 1280),
		_get_user_arg_int("--qa-height=", 720)
	)
	root.mode = Window.MODE_WINDOWED
	root.size = requested_size
	root.position = Vector2i(40, 40)
	for _frame in range(6):
		await process_frame


func _get_outside_band_max_rgb(image: Image, game_offset: Vector2, game_size: Vector2, image_scale: Vector2) -> float:
	var image_size := image.get_size()
	var x0 := clampi(int(floor(game_offset.x * image_scale.x)), 0, image_size.x)
	var y0 := clampi(int(floor(game_offset.y * image_scale.y)), 0, image_size.y)
	var x1 := clampi(int(ceil((game_offset.x + game_size.x) * image_scale.x)), 0, image_size.x)
	var y1 := clampi(int(ceil((game_offset.y + game_size.y) * image_scale.y)), 0, image_size.y)
	var guard_x := maxi(2, int(ceil(image_scale.x * 2.0)))
	var guard_y := maxi(2, int(ceil(image_scale.y * 2.0)))
	var bands := [
		Rect2i(0, 0, maxi(0, x0 - guard_x), image_size.y),
		Rect2i(mini(image_size.x, x1 + guard_x), 0, maxi(0, image_size.x - x1 - guard_x), image_size.y),
		Rect2i(x0, 0, maxi(0, x1 - x0), maxi(0, y0 - guard_y)),
		Rect2i(x0, mini(image_size.y, y1 + guard_y), maxi(0, x1 - x0), maxi(0, image_size.y - y1 - guard_y)),
	]
	var max_rgb := 0.0
	for band_value in bands:
		var band: Rect2i = band_value
		max_rgb = maxf(max_rgb, _scan_rect_max_rgb(image, band, 8))
	return max_rgb


func _scan_rect_max_rgb(image: Image, rect: Rect2i, stride: int) -> float:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var max_rgb := 0.0
	var end_x := rect.position.x + rect.size.x
	var end_y := rect.position.y + rect.size.y
	for y in range(rect.position.y, end_y, maxi(1, stride)):
		for x in range(rect.position.x, end_x, maxi(1, stride)):
			var pixel := image.get_pixel(x, y)
			max_rgb = maxf(max_rgb, pixel.r + pixel.g + pixel.b)
	return max_rgb


func _build_video_frame_signature(image: Image, game_offset: Vector2, game_size: Vector2, image_scale: Vector2) -> Array:
	var signature: Array[int] = []
	for y_ratio in [0.16, 0.30, 0.44, 0.58, 0.72, 0.86]:
		for x_ratio in [0.34, 0.42, 0.50, 0.58, 0.66]:
			var logical_position := game_offset + Vector2(game_size.x * float(x_ratio), game_size.y * float(y_ratio))
			var pixel := image.get_pixelv(_to_image_position(logical_position, image_scale, image.get_size()))
			signature.append(int(round(pixel.r * 255.0)))
			signature.append(int(round(pixel.g * 255.0)))
			signature.append(int(round(pixel.b * 255.0)))
	return signature


func _signature_distance(left: Array, right: Array) -> int:
	var distance := 0
	for index in range(mini(left.size(), right.size())):
		distance += absi(int(left[index]) - int(right[index]))
	return distance


func _to_image_position(logical_position: Vector2, image_scale: Vector2, image_size: Vector2i) -> Vector2i:
	var mapped := Vector2i((logical_position * image_scale).round())
	return Vector2i(
		clampi(mapped.x, 0, maxi(0, image_size.x - 1)),
		clampi(mapped.y, 0, maxi(0, image_size.y - 1))
	)


func _get_user_arg_int(prefix: String, fallback: int) -> int:
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with(prefix):
			return maxi(1, int(text.substr(prefix.length())))
	return fallback


func _is_headless_runtime() -> bool:
	return OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
