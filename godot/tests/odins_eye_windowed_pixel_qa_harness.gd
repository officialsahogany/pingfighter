extends SceneTree

## 오딘의 눈 windowed 픽셀 QA 하니스 (비-headless 전용).
##
## focused 게이트용 스모크가 아니라 재생산 가능한 픽셀 QA 증적 생성기다.
## `Godot_console.exe --path godot --script res://tests/odins_eye_windowed_pixel_qa_harness.gd -- --commit=<oid>`
## 로 실행하면 1280x750(scale 1.0)과 1920x1125(scale 1.5) 두 pass를 돌고,
## pass마다 프레임당 하나의 시나리오를 렌더-캡처해 검증한다:
##   ① 이동 중 기울기·눈동자(player_speed: idle vs speed=8 프레임 발산)
##   ② 부활 BANG 프레임 대형 플래시(빌드 프레임 대비 밝기 급증)
##   ③ 사망 폭발 구간 파편/충격파 픽셀
##   ④ 변신 중 stage1 full draw = 오딘 본체 실경로 렌더 + spy 봉인
##      (sprite_renderer 0회 / odin draw_player 1회 — 픽셀 임계만으로는
##      스와프가 빠지고 다른 본체가 그려져도 GREEN일 수 있다)
##   ⑤ Commando 무기 오버레이: baseline(비변신)에서 무기 마커 픽셀이 실제로
##      렌더됨을 먼저 증명하고, 같은 fixture+변신에서 0픽셀(억제)을 봉인
##   ⑥ FX 호스트 좌우 경계 플레이필드 클립(레터박스 픽셀 0)
##
## 증적은 fail-closed다: 귀속 커밋은 git HEAD를 직접 조회해 확정하고
## (--commit 주장과 불일치=RED, HEAD 조회 실패=RED, dirty=내용 지문 기록:
## tracked/untracked=파일별 내용 sha256 롤업(상태 코드·삭제 마커 포함),
## .godot/** 생성 캐시=개수+제외 근거, git 조회 실패=즉시 RED),
## 실행마다 세대별 디렉터리 `odin_pixel_qa_<UTC ts>_<usec>_<pid>_<commit12>/`
## 에 저장한다(선존재=병렬 충돌 거부). save_png 실패·기대 파일 수 불일치·
## 해시 형식 오류는 RED이며, manifest.txt는 파일셋·해시 검증을 전부 끝낸
## 뒤 result를 확정해 기록하고 readback 대조까지 통과해야 발행이 성립한다.
## headless로 실행되면 검증 없이 skip 종료한다(픽셀 없음 = 증적 무의미).

const OdinsEyePresentationRenderer := preload("res://scripts/items/odins_eye_presentation_renderer.gd")
const OdinsEyePresentationFxHost := preload("res://scripts/items/odins_eye_presentation_fx_host.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const OdinsEyeState := preload("res://scripts/items/odins_eye_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")


class QaOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"special_gauge": 150.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(300.0, 400.0),
		"ball_pos": Vector2(380.0, 150.0),
		"ball_vel": Vector2(0.0, -6.0),
		"ball_active": true,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class QaRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null

	func get_cached_instance(_key: String) -> Object:
		return null

const EVIDENCE_ROOT := "C:/Users/woduq/bosspong_backups/qa_evidence"
const GAME_SIZE := Vector2(760.0, 750.0)
const BACKGROUND := Color(0.015, 0.018, 0.025, 1.0)
# 무기 오버레이 fixture 마커(순적색) — 오딘 팔레트(보라/금)와 겹치지 않아
# 픽셀 카운트로 무기 렌더 여부를 판정한다.
const WEAPON_MARKER := Color(1.0, 0.05, 0.05, 1.0)
const SCENARIOS: Array[String] = [
	"idle_body", "moving_body", "revival_build", "revival_bang",
	"death_explosion", "stage_full_draw",
	"commando_weapon_baseline", "commando_weapon_suppressed",
	"clip_host_only",
]

const PASSES: Array = [
	{"label": "1280", "view": Vector2i(1280, 750), "scale": 1.0},
	{"label": "1920", "view": Vector2i(1920, 1125), "scale": 1.5},
]

var _failures: Array[String] = []
var _pass_index := 0
var _scenario_index := 0
var _frame_count := 0
var _probe: OdinScenarioProbe = null
var _host: Node = null
var _signatures: Dictionary = {}
var _run_dir := ""
var _tested_commit := "untracked-run"
var _head_oid_full := ""
var _dirty_fingerprint_lines: Array = []
var _saved_files: Array[String] = []


class SpySpriteRenderer:
	extends RefCounted

	var draw_calls := 0

	func draw(
		_canvas: CanvasItem,
		_context: Dictionary,
		_player_visual_rect: Rect2,
		_player_move_active: bool,
		_player_pos: Vector2,
		_paddle_size: Vector2,
		_shake_offset: Vector2
	) -> void:
		draw_calls += 1

	func clear_transient_canvas_items() -> void:
		pass


class SpyOdinRenderer:
	extends RefCounted

	var inner: Object = null
	var draw_player_calls := 0

	func draw_player(
		canvas: CanvasItem,
		context: Dictionary,
		player_pos: Vector2,
		paddle_size: Vector2,
		shake_offset: Vector2
	) -> Rect2:
		draw_player_calls += 1
		return inner.draw_player(canvas, context, player_pos, paddle_size, shake_offset)


class OdinScenarioProbe:
	extends Node2D

	var renderer: Object = OdinsEyePresentationRenderer.new()
	var actor_renderer: Object = Stage1PlayerActorRenderer.new()
	var scenario := "idle_body"
	var game_offset := Vector2.ZERO
	var render_scale := 1.0
	var draw_count := 0
	var spy_sprite: SpySpriteRenderer = null
	var spy_odin: SpyOdinRenderer = null
	var weapon_texture: Texture2D = null

	var _real_sprite_renderer: Object = null
	var _real_odin_renderer: Object = null

	func install_spies() -> void:
		if _real_sprite_renderer == null:
			_real_sprite_renderer = actor_renderer.sprite_renderer
			_real_odin_renderer = actor_renderer.odins_eye_presentation_renderer
		spy_sprite = SpySpriteRenderer.new()
		spy_odin = SpyOdinRenderer.new()
		spy_odin.inner = OdinsEyePresentationRenderer.new()
		actor_renderer.sprite_renderer = spy_sprite
		actor_renderer.odins_eye_presentation_renderer = spy_odin

	# spy는 시나리오-로컬이다 — 남겨두면 다음 시나리오의 실 렌더러 픽셀
	# fixture(commando baseline 등)가 통째로 바꿔치기돼 조용히 빈 화면이 된다.
	func uninstall_spies() -> void:
		if _real_sprite_renderer != null:
			actor_renderer.sprite_renderer = _real_sprite_renderer
			actor_renderer.odins_eye_presentation_renderer = _real_odin_renderer

	func _make_weapon_texture() -> Texture2D:
		if weapon_texture == null:
			var weapon_image := Image.create(48, 24, false, Image.FORMAT_RGBA8)
			weapon_image.fill(WEAPON_MARKER)
			weapon_texture = ImageTexture.create_from_image(weapon_image)
		return weapon_texture

	func _commando_stage_context(transformed: bool) -> Dictionary:
		var stage_context := {
			"selected_character_type": "soldier",
			"player_pos": ACTOR_POS,
			"player_paddle_size": PADDLE_SIZE,
			"player_speed": 6.0,
			"player_anim_clock": 2.0,
			"game_offset": game_offset,
			"render_scale": render_scale,
			"commando_current_weapon_id": "ak47",
			"commando_weapon_fire_active": true,
			"commando_weapon_fire_sheet": _make_weapon_texture(),
			"commando_weapon_fire_grid_cols": 1,
			"commando_weapon_fire_grid_rows": 1,
			"commando_weapon_fire_frame_count": 1,
			"commando_weapon_fire_frame": 0,
			"player_commando_weapon_fire_draw_size": Vector2(120.0, 80.0),
		}
		if transformed:
			stage_context["odins_eye_context"] = {
				"transformed": true,
				"penalty_active": true,
				"revival_animation_active": false,
				"death_animation_active": false,
				"dark_swamp": {"spikes": [], "fragments": []},
			}
		return stage_context

	# 게임 캔버스 중앙 부근의 공통 배우 위치.
	const ACTOR_POS := Vector2(300.0, 420.0)
	const PADDLE_SIZE := Vector2(155.0, 50.0)

	func _odin_context(extra: Dictionary) -> Dictionary:
		var odins := {
			"transformed": true,
			"penalty_active": true,
			"revival_animation_active": false,
			"death_animation_active": false,
			"dark_swamp": {"spikes": [], "fragments": []},
		}
		odins.merge(extra, true)
		return {"odins_eye_context": odins, "player_anim_clock": 2.0}

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2(-4000.0, -4000.0), Vector2(8000.0, 8000.0)), BACKGROUND, true)
		if scenario == "clip_host_only":
			return  # 호스트(별도 노드)만 그린다 — 레터박스 누수 검사용.
		draw_set_transform(game_offset, 0.0, Vector2(render_scale, render_scale))
		match scenario:
			"idle_body":
				renderer.draw_player(self, _odin_context({}), ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
			"moving_body":
				var moving: Dictionary = _odin_context({})
				moving["player_speed"] = 8.0
				renderer.draw_player(self, moving, ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
			"revival_build":
				renderer.draw_overlay(self, _odin_context({
					"revival_animation_active": true,
					"revival_progress": 0.5,
					"revival_timer_sec": OdinsEyeState.REVIVAL_EVENT_SEC * 0.5,
				}), ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
			"revival_bang":
				var bang_progress: float = OdinsEyeState.REVIVAL_BURST_PREP_FRAC \
					+ OdinsEyeState.REVIVAL_BANG_T * (1.0 - OdinsEyeState.REVIVAL_BURST_PREP_FRAC)
				renderer.draw_overlay(self, _odin_context({
					"revival_animation_active": true,
					"revival_progress": bang_progress,
					"revival_timer_sec": OdinsEyeState.REVIVAL_EVENT_SEC * (1.0 - bang_progress),
				}), ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
			"death_explosion":
				var death: Dictionary = _odin_context({
					"death_animation_active": true,
					"death_phase": "explosion",
					"death_phase_progress": 0.5,
					"death_overall_progress": 2.5 / 4.5,
					"death_energy_buildup": 1.0,
				})
				renderer.draw_player(self, death, ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
				renderer.draw_overlay(self, death, ACTOR_POS, PADDLE_SIZE, Vector2.ZERO)
			"stage_full_draw":
				var stage_context: Dictionary = _odin_context({})
				stage_context["selected_character_type"] = "smasher"
				stage_context["player_pos"] = ACTOR_POS
				stage_context["player_paddle_size"] = PADDLE_SIZE
				stage_context["player_speed"] = 6.0
				stage_context["game_offset"] = game_offset
				stage_context["render_scale"] = render_scale
				actor_renderer.draw(self, stage_context, Vector2.ZERO)
			"commando_weapon_baseline":
				actor_renderer.draw(self, _commando_stage_context(false), Vector2.ZERO)
			"commando_weapon_suppressed":
				actor_renderer.draw(self, _commando_stage_context(true), Vector2.ZERO)


func _init() -> void:
	if _is_headless_run():
		print("odins_eye_windowed_pixel_qa_harness: skipped (headless run has no pixels)")
		quit(0)
		return
	# 귀속은 호출자 주장(--commit)이 아니라 실제 저장소 HEAD가 진실이다 —
	# 인자를 그대로 신뢰하면 다른/더러운 코드로 실행해도 원하는 커밋의
	# 증적으로 표기할 수 있다. HEAD를 직접 조회해 인자와 불일치하면 RED,
	# dirty면 tracked/untracked fingerprint를 manifest에 함께 기록한다.
	# 대체 인덱스/작업트리 오염 차단: 호출 셸에 GIT_INDEX_FILE 등이 남아
	# 있으면 자식 git이 그 인덱스를 물어 전 파일이 삭제+언트랙으로 판독된다
	# (dirty_tracked가 커밋 트리 파일 수와 일치하는 전형 신호) — 귀속이
	# 통째로 무효가 되므로 실행 자체를 거부한다.
	for polluting_key in ["GIT_INDEX_FILE", "GIT_DIR", "GIT_WORK_TREE"]:
		if OS.has_environment(polluting_key):
			push_error("odins_eye_windowed_pixel_qa_harness: %s 환경 변수가 설정됨 — 대체 인덱스/작업트리 오염으로 귀속 불가, 해제 후 재실행" % polluting_key)
			quit(1)
			return
	var head_oid: String = _git_head_oid()
	if head_oid.is_empty():
		push_error("odins_eye_windowed_pixel_qa_harness: git HEAD 조회 실패 — 귀속 불가로 거부")
		quit(1)
		return
	var claimed_commit := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--commit="):
			claimed_commit = str(arg).trim_prefix("--commit=")
	if not claimed_commit.is_empty() and not head_oid.begins_with(claimed_commit):
		push_error("odins_eye_windowed_pixel_qa_harness: --commit 주장(%s)이 실제 HEAD(%s)와 불일치" % [claimed_commit, head_oid])
		quit(1)
		return
	_tested_commit = head_oid.substr(0, 12)
	_head_oid_full = head_oid
	var fingerprint: Dictionary = _git_dirty_content_fingerprint()
	if not bool(fingerprint.get("ok", false)):
		push_error("odins_eye_windowed_pixel_qa_harness: dirty 지문 계산 실패 — %s" % str(fingerprint.get("error", "unknown")))
		quit(1)
		return
	_dirty_fingerprint_lines = fingerprint.get("lines", [])
	if bool(fingerprint.get("dirty", false)):
		_tested_commit += "-dirty"
	# 세대 유일성: 초 단위 스탬프만으로는 같은 초·같은 커밋의 병렬 실행이
	# 기존 디렉터리를 재사용해 파일을 덮는다 — usec+PID를 붙이고 선존재를
	# 거부한다.
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	_run_dir = "%s/odin_pixel_qa_%s_%d_%d_%s" % [EVIDENCE_ROOT, stamp, Time.get_ticks_usec(), OS.get_process_id(), _tested_commit]
	if DirAccess.dir_exists_absolute(_run_dir):
		push_error("odins_eye_windowed_pixel_qa_harness: evidence dir already exists (parallel-run collision): %s" % _run_dir)
		quit(1)
		return
	var make_dir_error: int = DirAccess.make_dir_recursive_absolute(_run_dir)
	if make_dir_error != OK:
		push_error("odins_eye_windowed_pixel_qa_harness: evidence dir creation failed (%d): %s" % [make_dir_error, _run_dir])
		quit(1)
		return
	_start_pass()


func _git_head_oid() -> String:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute("git", ["-C", project_root, "rev-parse", "HEAD"], output, false)
	if exit_code != 0 or output.is_empty():
		return ""
	var oid: String = str(output[0]).strip_edges().split("\n")[0].strip_edges()
	if oid.length() != 40:
		return ""
	return oid


# dirty 내용 지문: 이 리포는 의도적 WIP 워크트리라 dirty 실행을 거부하는
# 대신 실제 테스트된 코드 "바이트"를 봉인한다 — status의 상태·경로 문자열
# 지문은 같은 파일을 다른 내용으로 고쳐도 동일해서 귀속이 성립하지 않는다.
# tracked 변경 = git diff HEAD --binary 출력의 내용 sha256, 비생성
# untracked = 파일별 내용 sha256의 롤업. .godot/** 생성 캐시는 코드가
# 아니므로(res:// 임포트 시 재생성) 개수+제외 근거만 기록한다. 어떤 git
# 조회든 실패하면 폴백 문자열로 계속 가지 않고 즉시 실패를 올린다.
func _git_dirty_content_fingerprint() -> Dictionary:
	var toplevel: String = _git_query(["rev-parse", "--show-toplevel"])
	if toplevel.is_empty():
		return {"ok": false, "error": "rev-parse --show-toplevel failed"}
	toplevel = toplevel.strip_edges()
	var status_result: Dictionary = _git_query_checked(["status", "--porcelain", "--untracked-files=all"])
	if not bool(status_result.get("ok", false)):
		return {"ok": false, "error": "status --porcelain failed"}
	# 전체 출력에서 strip_edges()를 쓰면 첫 행의 선행 공백 상태 열(" M path"의
	# unstaged 마커)이 잘려 status_code와 경로가 한 칸씩 밀린다 — 우측
	# 개행만 제거하고 각 행의 첫 두 열은 그대로 보존한다.
	var status_text: String = str(status_result.get("text", "")).strip_edges(false, true)
	if status_text.is_empty():
		return {"ok": true, "dirty": false, "lines": ["worktree: clean"]}
	var tracked_entries: Array[Dictionary] = []
	var untracked_paths: Array[String] = []
	var generated_count := 0
	for raw_line in status_text.split("\n"):
		var parsed: Dictionary = parse_porcelain_line(raw_line)
		if parsed.is_empty():
			continue
		var status_code: String = str(parsed.get("status", ""))
		var path: String = str(parsed.get("path", ""))
		if status_code == "??":
			if path.contains("/.godot/") or path.begins_with(".godot/"):
				generated_count += 1
			else:
				untracked_paths.append(path)
		else:
			tracked_entries.append(parsed)
	var lines: Array = ["worktree: dirty"]
	# tracked 변경도 파일별 워킹트리 내용 sha256으로 봉인한다(상태 코드
	# 포함 정렬 롤업 — 같은 경로를 다른 내용으로 고치면 지문이 달라진다).
	# git diff HEAD --binary 스트림은 대량 변경 트리(임포트 직후 워크트리
	# 등)에서 OS.execute 파이프 버퍼 한계를 넘어 조회 자체가 실패한다 —
	# 삭제(D)는 워킹트리에 파일이 없으므로 deleted 마커로 봉인한다.
	if tracked_entries.is_empty():
		lines.append("dirty_tracked: none")
	else:
		var tracked_rollup: Array[String] = []
		for entry in tracked_entries:
			var status_code: String = str(entry.get("status", ""))
			var entry_path: String = str(entry.get("path", ""))
			var old_path: String = str(entry.get("old_path", ""))
			# rename/copy는 new 경로의 실제 내용을 해시한다 — old->new 전체를
			# 단일 경로로 취급하면 존재하지 않는 파일로 deleted 처리돼 rename
			# 후 새 파일 내용이 바뀌어도 지문이 같아진다.
			var label: String = entry_path if old_path.is_empty() else "%s -> %s" % [old_path, entry_path]
			var entry_absolute := "%s/%s" % [toplevel, entry_path]
			if not FileAccess.file_exists(entry_absolute):
				tracked_rollup.append("%s %s deleted" % [status_code, label])
				continue
			var entry_digest: String = FileAccess.get_sha256(entry_absolute)
			if entry_digest.length() != 64:
				return {"ok": false, "error": "tracked file hash failed: %s" % entry_path}
			tracked_rollup.append("%s %s %s" % [status_code, label, entry_digest])
		tracked_rollup.sort()
		lines.append("dirty_tracked: %d-entries content_sha256=%s" % [tracked_entries.size(), "\n".join(tracked_rollup).sha256_text()])
	if untracked_paths.is_empty():
		lines.append("dirty_untracked: none")
	else:
		untracked_paths.sort()
		var rollup_lines: Array[String] = []
		for path in untracked_paths:
			var absolute_path := "%s/%s" % [toplevel, path]
			if not FileAccess.file_exists(absolute_path):
				return {"ok": false, "error": "untracked file unreadable: %s" % path}
			var digest: String = FileAccess.get_sha256(absolute_path)
			if digest.length() != 64:
				return {"ok": false, "error": "untracked file hash failed: %s" % path}
			rollup_lines.append("%s %s" % [digest, path])
		lines.append("dirty_untracked: %d-files content_sha256=%s" % [untracked_paths.size(), "\n".join(rollup_lines).sha256_text()])
	if generated_count > 0:
		lines.append("dirty_generated: %d-entries excluded (.godot/** import cache — regenerated from res://, not tested code)" % generated_count)
	return {"ok": true, "dirty": true, "lines": lines}


func _git_query(args: Array) -> String:
	var result: Dictionary = _git_query_checked(args)
	return str(result.get("text", "")) if bool(result.get("ok", false)) else ""


func _git_query_checked(args: Array) -> Dictionary:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var full_args: Array = ["-C", project_root]
	full_args.append_array(args)
	var output: Array = []
	var exit_code: int = OS.execute("git", full_args, output, false)
	if exit_code != 0:
		return {"ok": false}
	return {"ok": true, "text": str(output[0]) if not output.is_empty() else ""}


# porcelain v1 한 행 파서. 첫 두 열(XY)을 그대로 보존하고(선행 공백=unstaged
# 마커), R/C(rename/copy)는 old -> new를 분리해 new 경로를 해시 대상으로
# 삼는다. NUL 구분(-z) 형식이 원칙상 더 안전하지만 GDScript String이 NUL을
# 나를 수 없어(OS.execute 출력이 C-string 경계에서 소실) v1 비-z를 쓰고,
# 공백/화살표가 든 경로는 porcelain이 반드시 따옴표로 감싸므로 따옴표-인식
# 스플리터로 모호성을 제거한다. 반환: {status, path, old_path} — old_path는
# rename/copy에만 비어 있지 않다. 형식 미달 행은 {}.
static func parse_porcelain_line(raw_line: String) -> Dictionary:
	var line: String = raw_line.trim_suffix("\r")
	if line.length() < 4:
		return {}
	var status_code: String = line.substr(0, 2)
	var payload: String = line.substr(3)
	# rename/copy는 X열(staged)뿐 아니라 Y열(worktree)에도 올 수 있다
	# (" R old -> new", "MR ..." 등) — 두 상태 열 중 어느 쪽이든 R/C면
	# old -> new payload다.
	if status_code.contains("R") or status_code.contains("C"):
		var split: Dictionary = _split_rename_payload(payload)
		if split.is_empty():
			return {}
		return {
			"status": status_code,
			"path": _unquote_git_path(str(split.get("new", ""))),
			"old_path": _unquote_git_path(str(split.get("old", ""))),
		}
	return {"status": status_code, "path": _unquote_git_path(payload), "old_path": ""}


# rename payload "old -> new" 분해. old가 따옴표로 감싸였으면 닫는 따옴표
# (이스케이프 \" 감안)까지가 old — 경로 안의 리터럴 " -> "는 그 경로가
# 반드시 따옴표로 감싸이므로 스플리터와 충돌하지 않는다.
static func _split_rename_payload(payload: String) -> Dictionary:
	if payload.begins_with("\""):
		var index := 1
		while index < payload.length():
			if payload[index] == "\\":
				index += 2
				continue
			if payload[index] == "\"":
				break
			index += 1
		if index >= payload.length():
			return {}
		var old_quoted: String = payload.substr(0, index + 1)
		var remainder: String = payload.substr(index + 1)
		if not remainder.begins_with(" -> "):
			return {}
		return {"old": old_quoted, "new": remainder.trim_prefix(" -> ")}
	var arrow_index: int = payload.find(" -> ")
	if arrow_index < 0:
		return {}
	return {"old": payload.substr(0, arrow_index), "new": payload.substr(arrow_index + 4)}


# porcelain 경로 언이스케이프: 비ASCII/공백 경로는 따옴표로 감싸이고
# 비ASCII 바이트는 백슬래시-nnn octal로 이스케이프된다(quotepath 기본,
# core.quotepath=false는 실 UTF-8 바이트가 파이프 코드페이지에서 깨짐). 파이프가
# ASCII만 나르므로 인코딩 손상이 없고, octal을 바이트로 복원해 UTF-8
# 경로를 재구성한다. 복원 실패 경로는 파일 접근 실패가 RED로 잡는다.
static func _unquote_git_path(raw_path: String) -> String:
	var path: String = raw_path.strip_edges()
	if not (path.begins_with("\"") and path.ends_with("\"") and path.length() >= 2):
		return path
	path = path.substr(1, path.length() - 2)
	var bytes := PackedByteArray()
	var index := 0
	while index < path.length():
		var character: String = path[index]
		if character != "\\":
			var utf8: PackedByteArray = character.to_utf8_buffer()
			bytes.append_array(utf8)
			index += 1
			continue
		if index + 1 >= path.length():
			break
		var next_char: String = path[index + 1]
		if next_char == "\"" or next_char == "\\":
			bytes.append(next_char.unicode_at(0))
			index += 2
		elif next_char == "t":
			bytes.append(9)
			index += 2
		elif next_char == "n":
			bytes.append(10)
			index += 2
		elif index + 3 < path.length() and next_char >= "0" and next_char <= "7":
			var octal_value: int = (path.substr(index + 1, 1).to_int() * 64
				+ path.substr(index + 2, 1).to_int() * 8
				+ path.substr(index + 3, 1).to_int())
			bytes.append(octal_value)
			index += 4
		else:
			index += 1
	return bytes.get_string_from_utf8()


func _start_pass() -> void:
	var pass_config: Dictionary = PASSES[_pass_index]
	var view: Vector2i = pass_config["view"]
	get_root().size = view
	DisplayServer.window_set_size(view)
	var render_scale: float = float(pass_config["scale"])
	var game_offset := Vector2((float(view.x) - GAME_SIZE.x * render_scale) * 0.5, 0.0)
	if _probe != null:
		_probe.queue_free()
	if _host != null:
		_host.queue_free()
		_host = null
	_probe = OdinScenarioProbe.new()
	_probe.game_offset = game_offset
	_probe.render_scale = render_scale
	get_root().add_child(_probe)
	_signatures = {}
	_scenario_index = 0
	_begin_scenario()


func _begin_scenario() -> void:
	var scenario: String = SCENARIOS[_scenario_index]
	_probe.scenario = scenario
	if scenario in ["stage_full_draw", "commando_weapon_suppressed"]:
		_probe.install_spies()
	else:
		_probe.uninstall_spies()
	if _host != null:
		_host.queue_free()
		_host = null
	if scenario == "clip_host_only":
		var pass_config: Dictionary = PASSES[_pass_index]
		var render_scale: float = float(pass_config["scale"])
		var view: Vector2i = pass_config["view"]
		var game_offset := Vector2((float(view.x) - GAME_SIZE.x * render_scale) * 0.5, 0.0)
		_host = OdinsEyePresentationFxHost.new()
		get_root().add_child(_host)
		# 실 runtime으로 잔상 payload를 생성한다 — 합성 dict는 렌더러 스키마와
		# 어긋나 진단을 오염시킨다. 잔상 하나는 좌측 경계 밖(x<0), 하나는
		# 플레이필드 중앙: 클립이 살아 있으면 레터박스 픽셀 0 + 중앙 잔상 렌더.
		var runtime: Object = MythicItemRuntime.new()
		var qa_owner := QaOwner.new()
		var qa_registry := QaRegistry.new()
		runtime.equip_item("odins_eye", qa_owner, qa_registry, {"revival_chance": 100.0}, false)
		runtime.try_trigger_odins_eye_revival("round", 0.0)
		runtime.odins_eye_runtime.update_runtime(runtime, 231.0, qa_owner, qa_registry)
		runtime.consume_odins_eye_revival_finalize_ready()
		var afterimage_state: Object = runtime.odins_eye_afterimage_state
		afterimage_state.clear_all()
		afterimage_state.create_afterimage(Vector2(-60.0, 420.0), 155.0, 50.0)
		afterimage_state.last_afterimage_pos = Vector2.INF
		afterimage_state.afterimage_spawn_cooldown_frames = 0.0
		afterimage_state.create_afterimage(Vector2(380.0, 420.0), 155.0, 50.0)
		_host.sync_state({
			"odins_eye_context": runtime.get_odins_eye_context(),
			"player_speed": 8.0,
		}, Vector2(-90.0, 400.0), Vector2(155.0, 50.0), Vector2.ZERO, {
			"game_offset": game_offset,
			"render_scale": render_scale,
		})
	_probe.queue_redraw()
	_frame_count = 0


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 4:
		return false
	_capture_scenario()
	_scenario_index += 1
	if _scenario_index < SCENARIOS.size():
		_begin_scenario()
		return false
	_verify_pass()
	_pass_index += 1
	if _pass_index < PASSES.size():
		_start_pass()
		return false
	_finalize_evidence()
	if _failures.is_empty():
		print("odins_eye_windowed_pixel_qa_harness: ok (evidence: %s)" % _run_dir)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


# 증적 fail-closed 마감: 기대 파일 수(2 pass × 시나리오 수) 대조 후 tested
# commit·결과·파일별 sha256을 manifest.txt로 기록한다. 저장 실패·수 불일치·
# manifest 기록 실패 전부 RED — 메모리 이미지만으로 ok가 나가면 증적이
# 유실돼도 통과가 조용히 조작된다.
func _finalize_evidence() -> void:
	# 1단계: 파일셋·해시 검증을 전부 끝낸다 — result는 이 검증까지 반영해
	# 결정해야 한다(존재/해시 검사 전에 result를 쓰면 fail-closed가 아니다).
	var expected_count: int = PASSES.size() * SCENARIOS.size()
	if _saved_files.size() != expected_count:
		_failures.append("evidence file count mismatch: saved %d, expected %d" % [_saved_files.size(), expected_count])
	var file_lines: Array[String] = []
	for file_name in _saved_files:
		var path := "%s/%s" % [_run_dir, file_name]
		if not FileAccess.file_exists(path):
			_failures.append("evidence file missing on disk: %s" % file_name)
			file_lines.append("file: %s sha256=MISSING" % file_name)
			continue
		var digest: String = FileAccess.get_sha256(path)
		if digest.length() != 64:
			_failures.append("evidence file hash invalid (%d chars): %s" % [digest.length(), file_name])
		file_lines.append("file: %s sha256=%s" % [file_name, digest])
	# 2단계: 모든 검증이 끝난 뒤에야 result를 확정하고 기록한다.
	var manifest_lines: Array[String] = []
	manifest_lines.append("harness: odins_eye_windowed_pixel_qa_harness")
	manifest_lines.append("tested_commit: %s" % _tested_commit)
	manifest_lines.append("head_oid: %s" % _head_oid_full)
	for fingerprint_line in _dirty_fingerprint_lines:
		manifest_lines.append(str(fingerprint_line))
	manifest_lines.append("generated_utc: %s" % Time.get_datetime_string_from_system(true))
	manifest_lines.append("result: %s" % ("ok" if _failures.is_empty() else "FAILED"))
	for failure in _failures:
		manifest_lines.append("failure: %s" % failure)
	manifest_lines.append_array(file_lines)
	var manifest_text: String = "\n".join(manifest_lines) + "\n"
	var manifest_path := "%s/manifest.txt" % _run_dir
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest == null:
		_failures.append("evidence manifest write failed (%d)" % FileAccess.get_open_error())
		return
	manifest.store_string(manifest_text)
	manifest.close()
	# 3단계: readback — 디스크의 manifest가 쓴 내용과 완전히 일치해야
	# 발행이 성립한다(store_string 성공 반환만으로는 유실을 못 잡는다).
	var readback: String = FileAccess.get_file_as_string(manifest_path)
	if readback != manifest_text:
		_failures.append("evidence manifest readback mismatch (wrote %d chars, read %d)" % [manifest_text.length(), readback.length()])


func _weapon_marker_pixels(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.75 and color.g < 0.3 and color.b < 0.3:
				count += 1
	return count


func _capture_scenario() -> void:
	var pass_config: Dictionary = PASSES[_pass_index]
	var label: String = str(pass_config["label"])
	var scenario: String = SCENARIOS[_scenario_index]
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		_failures.append("[%s/%s] viewport texture unavailable" % [label, scenario])
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.get_width() <= 0:
		_failures.append("[%s/%s] capture failed" % [label, scenario])
		return
	var file_name := "odin_pixel_qa_%s_%s.png" % [label, scenario]
	var save_error: int = image.save_png("%s/%s" % [_run_dir, file_name])
	if save_error != OK:
		_failures.append("[%s/%s] evidence save_png failed (%d)" % [label, scenario, save_error])
	else:
		_saved_files.append(file_name)
	_signatures[scenario] = {
		"image": image,
		"signature": _frame_signature(image),
		"spies": {
			"sprite_calls": _probe.spy_sprite.draw_calls if _probe.spy_sprite != null else -1,
			"odin_calls": _probe.spy_odin.draw_player_calls if _probe.spy_odin != null else -1,
		},
	}
	_probe.spy_sprite = null
	_probe.spy_odin = null


func _verify_pass() -> void:
	var pass_config: Dictionary = PASSES[_pass_index]
	var label: String = str(pass_config["label"])
	var render_scale: float = float(pass_config["scale"])
	var view: Vector2i = pass_config["view"]
	var game_offset := Vector2((float(view.x) - GAME_SIZE.x * render_scale) * 0.5, 0.0)
	for scenario in SCENARIOS:
		if not _signatures.has(scenario):
			return

	# ① 본체 가시 + 기울기·눈동자 발산.
	var idle: Dictionary = _signatures["idle_body"]["signature"]
	var moving: Dictionary = _signatures["moving_body"]["signature"]
	_check(int(idle.get("active_count", 0)) > 400, "[%s] 변신 본체(정지) 픽셀 렌더, got %d" % [label, int(idle.get("active_count", 0))])
	_check(int(moving.get("active_count", 0)) > 400, "[%s] 변신 본체(이동) 픽셀 렌더" % label)
	var divergence: int = _frame_divergence(
		_signatures["idle_body"]["image"],
		_signatures["moving_body"]["image"]
	)
	# speed=8의 기울기(≈5.5°)·눈동자 시프트는 미묘하지만 0이 아니어야 한다 —
	# 전체 context 관통이 끊기면(player_speed 소실) 발산이 정확히 0이 된다.
	_check(divergence > 8, "[%s] player_speed 반영: 이동 기울기·눈동자 픽셀 발산(%d)" % [label, divergence])

	# ② 부활 BANG 플래시 급증.
	var build_brightness: float = float(_signatures["revival_build"]["signature"].get("brightness_sum", 0.0))
	var bang_brightness: float = float(_signatures["revival_bang"]["signature"].get("brightness_sum", 0.0))
	_check(
		bang_brightness > build_brightness * 1.6 and bang_brightness > 1000.0,
		"[%s] 부활 BANG 대형 플래시(빌드 %.0f → BANG %.0f)" % [label, build_brightness, bang_brightness]
	)

	# ③ 사망 폭발 파편/충격파.
	_check(
		int(_signatures["death_explosion"]["signature"].get("active_count", 0)) > 800,
		"[%s] 사망 폭발 파편/충격파 픽셀, got %d" % [label, int(_signatures["death_explosion"]["signature"].get("active_count", 0))]
	)

	# ④ stage1 full draw 실경로 렌더 + spy 봉인. 픽셀 임계만으로는 오딘
	# 스와프가 빠지고 다른 본체가 그려져도 GREEN일 수 있다 — 일반 스프라이트
	# 0회 / 오딘 draw_player 정확 1회를 함께 봉인한다.
	_check(
		int(_signatures["stage_full_draw"]["signature"].get("active_count", 0)) > 400,
		"[%s] stage1 full draw: 변신 중 오딘 본체 실경로 렌더, got %d" % [label, int(_signatures["stage_full_draw"]["signature"].get("active_count", 0))]
	)
	var full_draw_spies: Dictionary = _signatures["stage_full_draw"].get("spies", {})
	_check(
		int(full_draw_spies.get("sprite_calls", -1)) == 0,
		"[%s] 변신 full draw: 일반 sprite_renderer 호출 0회, got %d" % [label, int(full_draw_spies.get("sprite_calls", -1))]
	)
	_check(
		int(full_draw_spies.get("odin_calls", -1)) == 1,
		"[%s] 변신 full draw: 오딘 draw_player 정확 1회, got %d" % [label, int(full_draw_spies.get("odin_calls", -1))]
	)

	# ⑤ Commando 무기 오버레이 억제 — baseline이 먼저 무기 마커 픽셀을 실제로
	# 렌더함을 증명해야(fixture 유효성) 억제 0픽셀이 공허하지 않다.
	var baseline_weapon_pixels: int = _weapon_marker_pixels(_signatures["commando_weapon_baseline"]["image"])
	var suppressed_weapon_pixels: int = _weapon_marker_pixels(_signatures["commando_weapon_suppressed"]["image"])
	_check(
		baseline_weapon_pixels > 20,
		"[%s] commando baseline: 무기 오버레이 마커 픽셀 렌더(fixture 유효성), got %d" % [label, baseline_weapon_pixels]
	)
	_check(
		suppressed_weapon_pixels == 0,
		"[%s] commando 변신: 무기 오버레이 마커 픽셀 0(억제), got %d" % [label, suppressed_weapon_pixels]
	)
	var suppressed_spies: Dictionary = _signatures["commando_weapon_suppressed"].get("spies", {})
	_check(
		int(suppressed_spies.get("sprite_calls", -1)) == 0 and int(suppressed_spies.get("odin_calls", -1)) == 1,
		"[%s] commando 변신: sprite 0회 + 오딘 본체 1회" % label
	)

	# ⑤ 클립: 레터박스 픽셀 0 + 플레이필드 안에는 잔상 픽셀 존재.
	var clip_image: Image = _signatures["clip_host_only"]["image"]
	if game_offset.x > 8.0:
		var left_band := Rect2i(0, 0, int(game_offset.x) - 4, view.y)
		var right_start: int = int(game_offset.x + GAME_SIZE.x * render_scale) + 4
		var right_band := Rect2i(right_start, 0, view.x - right_start, view.y)
		_check(_band_foreign_pixels(clip_image, left_band) == 0, "[%s] 좌측 레터박스 누수 픽셀 0" % label)
		_check(_band_foreign_pixels(clip_image, right_band) == 0, "[%s] 우측 레터박스 누수 픽셀 0" % label)
	var playfield_band := Rect2i(int(game_offset.x), 0, int(GAME_SIZE.x * render_scale), view.y)
	_check(
		_band_foreign_pixels(clip_image, playfield_band) > 30,
		"[%s] 플레이필드 안에서는 잔상이 실제로 렌더(클립 검사의 유효성)" % label
	)


func _frame_signature(image: Image) -> Dictionary:
	var active_count := 0
	var brightness_sum := 0.0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var color: Color = image.get_pixel(x, y)
			var brightness: float = color.r + color.g + color.b
			if brightness > BACKGROUND.r + BACKGROUND.g + BACKGROUND.b + 0.06:
				active_count += 1
				brightness_sum += brightness
	return {"active_count": active_count, "brightness_sum": brightness_sum}


func _frame_divergence(image_a: Image, image_b: Image) -> int:
	var divergence := 0
	var width: int = mini(image_a.get_width(), image_b.get_width())
	var height: int = mini(image_a.get_height(), image_b.get_height())
	for y in range(0, height, 3):
		for x in range(0, width, 3):
			var color_a: Color = image_a.get_pixel(x, y)
			var color_b: Color = image_b.get_pixel(x, y)
			if absf(color_a.r - color_b.r) + absf(color_a.g - color_b.g) + absf(color_a.b - color_b.b) > 0.12:
				divergence += 1
	return divergence


func _band_foreign_pixels(image: Image, band: Rect2i) -> int:
	var foreign := 0
	var clipped: Rect2i = band.intersection(Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())))
	for y in range(clipped.position.y, clipped.end.y, 2):
		for x in range(clipped.position.x, clipped.end.x, 2):
			var color: Color = image.get_pixel(x, y)
			if absf(color.r - BACKGROUND.r) + absf(color.g - BACKGROUND.g) + absf(color.b - BACKGROUND.b) > 0.06:
				foreign += 1
	return foreign


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_headless_run() -> bool:
	if OS.get_cmdline_args().has("--headless"):
		return true
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		return true
	return OS.has_feature("headless")
