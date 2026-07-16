extends SceneTree

const OdinsEyePresentationFxHost := preload("res://scripts/items/odins_eye_presentation_fx_host.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BattlePlayfieldSceneDrawer := preload("res://scripts/core/battle_playfield_scene_drawer.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const OdinPixelQaHarness := preload("res://tests/odins_eye_windowed_pixel_qa_harness.gd")

var _failures: Array[String] = []


class ThreeArgsOneDefaultBuilder:
	extends RefCounted

	func build_scene_context(_owner: Object, _shake: Vector2, _registry = null) -> Dictionary:
		return {}


class ThreeArgsNoDefaultBuilder:
	extends RefCounted

	func build_scene_context(_owner: Object, _shake: Vector2, _registry) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host: Node = OdinsEyePresentationFxHost.new()
	get_root().add_child(host)
	host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	await process_frame
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "Odin presentation host should activate for revival overlay")
	_expect(bool(status.get("playfield_clip_active", false)), "Odin presentation host must clip to the full 760x750 playfield")
	_expect(bool(status.get("draw_bridge_inside_clip", false)), "Odin overlay draw bridge must remain inside the clip")
	_expect(status.get("game_offset", Vector2.ZERO) == Vector2(210.0, 35.0), "host should follow the battle game offset")
	_expect(is_equal_approx(float(status.get("render_scale", 0.0)), 1.2), "host should follow battle render scale")

	# Live screen shake must reach the detached host (the shell's canvas draw
	# transform carries the real shake, which child nodes do not inherit).
	host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2(4.0, 3.0), {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	_expect(
		host.get_debug_status().get("shake_offset", Vector2.ZERO) == Vector2(4.0, 3.0),
		"host must carry the live screen shake into the overlay draw"
	)

	# Direct lifecycle cleanup: the reset paths hide every live host through
	# the scene-tree cleanup group — no draw-idle heuristic that could hide a
	# legitimately live effect on a skipped redraw.
	var lifecycle_runtime: Object = MythicItemRuntime.new()
	lifecycle_runtime.should_pause_game() # _ensure_helpers_ready
	# Real score/serve boundary entry: the mythic FACADE reset_round routes
	# lifecycle -> odins runtime -> hide_all.
	lifecycle_runtime.reset_round()
	_expect(
		not bool(host.get_debug_status().get("active", true)),
		"the facade reset_round (score/serve boundary) must hide the detached host"
	)
	host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	_expect(
		bool(host.get_debug_status().get("active", false)),
		"a fresh sync must re-activate the host after a reset hide"
	)
	lifecycle_runtime.odins_eye_runtime.on_stage_advance(lifecycle_runtime)
	_expect(
		not bool(host.get_debug_status().get("active", true)),
		"stage advance must hide the detached host through the cleanup group"
	)
	host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	lifecycle_runtime.odins_eye_runtime.clear_on_unequip(lifecycle_runtime)
	_expect(
		not bool(host.get_debug_status().get("active", true)),
		"clear_on_unequip must hide the detached host directly (owner-null cancel contract)"
	)
	# A PENDING host (created but not yet attached — the renderer defers
	# add_child) must still be reachable by the reset cleanup.
	var pending_host: Node = OdinsEyePresentationFxHost.new()
	pending_host.prepare()
	pending_host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	OdinsEyePresentationFxHost.hide_all()
	_expect(
		not bool(pending_host.get_debug_status().get("active", true)),
		"hide_all must reach a pending (not-yet-attached) host"
	)
	# The clear APIs must be self-sufficient for pending hosts too — each is
	# called directly (not through the static helper the smoke used above).
	pending_host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	lifecycle_runtime.odins_eye_runtime.clear_after_victory(lifecycle_runtime)
	_expect(
		not bool(pending_host.get_debug_status().get("active", true)),
		"clear_after_victory must hide an unattached host on its own"
	)
	pending_host.sync_state({
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}, Vector2(-45.0, 700.0), Vector2(155.0, 50.0), Vector2.ZERO, {
		"game_offset": Vector2(210.0, 35.0),
		"render_scale": 1.2,
	})
	lifecycle_runtime.odins_eye_runtime.clear_after_death(lifecycle_runtime)
	_expect(
		not bool(pending_host.get_debug_status().get("active", true)),
		"clear_after_death must hide an unattached host on its own"
	)
	pending_host.free()
	host.set_active(false)

	# Arity feature-detect bounds: `args` already includes defaulted params, so
	# a 3-arg method with 1 default accepts 2..3 arguments — never 4. (The old
	# `requested <= declared + defaults` formula misjudged this as 4-callable.)
	var arity_drawer: Object = BattlePlayfieldSceneDrawer.new()
	var four_arg_capable := ThreeArgsOneDefaultBuilder.new()
	_expect(
		not arity_drawer._method_accepts_argument_count(four_arg_capable, "build_scene_context", 4),
		"a 3-declared/1-default method must NOT be judged 4-arg callable"
	)
	_expect(
		arity_drawer._method_accepts_argument_count(four_arg_capable, "build_scene_context", 3),
		"a 3-declared/1-default method must accept 3 arguments"
	)
	_expect(
		arity_drawer._method_accepts_argument_count(four_arg_capable, "build_scene_context", 2),
		"a 3-declared/1-default method must accept 2 arguments"
	)
	var three_arg_only := ThreeArgsNoDefaultBuilder.new()
	_expect(
		not arity_drawer._method_accepts_argument_count(three_arg_only, "build_scene_context", 4),
		"a 3-arg fake must NOT be judged 4-arg callable"
	)
	_expect(
		not arity_drawer._method_accepts_argument_count(three_arg_only, "build_scene_context", 2),
		"a 3-arg no-default method must reject 2 arguments"
	)
	status = host.get_debug_status()
	_expect(not bool(status.get("active", true)), "explicit cleanup should hide the detached Odin host")
	host.queue_free()

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var actor_renderer: Object = Stage1PlayerActorRenderer.new()
	var actor_context := {
		"game_offset": Vector2(150.0, 20.0),
		"render_scale": 1.1,
		"screen_shake_offset": Vector2(6.0, 2.0),
		"player_speed": 4.25,
		"player_anim_clock": 1.5,
		"status_effect_entries": [{"bulk": true}, {"bulk": true}],
		"boss_pos": Vector2(330.0, 25.0),
		"odins_eye_context": {
			"transformed": true,
			"revival_animation_active": true,
			"revival_timer_sec": 0.45,
			"dark_swamp": {"spikes": [], "fragments": []},
		},
	}
	actor_renderer._sync_odins_eye_overlay_host(
		canvas,
		actor_context,
		Vector2(300.0, 700.0),
		Vector2(155.0, 50.0),
		Vector2.ZERO
	)
	await process_frame
	var attached_host: Node = canvas.get_node_or_null("OdinsEyePresentationFxHost")
	_expect(attached_host != null, "player actor integration should attach the clipped Odin host")
	if attached_host != null:
		var attached_status: Dictionary = attached_host.get_debug_status()
		_expect(bool(attached_status.get("active", false)), "attached host should be active during revival")
		_expect(bool(attached_status.get("playfield_clip_active", false)), "attached host should keep its playfield clip")
		_expect(
			attached_status.get("shake_offset", Vector2.ZERO) == Vector2(6.0, 2.0),
			"actor integration must forward the context screen_shake_offset to the host"
		)
		# 전체 actor context 관통: player_speed(이동 기울기·눈동자)와
		# player_anim_clock(애니 클록)은 최상위 키 — sub-context만 넘기면
		# 소실돼 기울기 0/wall-clock fallback으로 고정된다.
		_expect(
			is_equal_approx(float(attached_host._context.get("player_speed", 0.0)), 4.25),
			"actor integration must forward the FULL actor context (player_speed) to the host"
		)
		_expect(
			is_equal_approx(float(attached_host._context.get("player_anim_clock", 0.0)), 1.5),
			"actor integration must forward player_anim_clock to the host"
		)
		# 최소 스냅샷 계약: 호스트는 이 dict를 매 렌더 프레임 duplicate(true)
		# 하므로, 렌더러가 조회하지 않는 대형 payload(스테이지/상태 트리 등)가
		# 통째로 실려오면 hot _draw() 경로 할당 회귀다.
		_expect(
			not attached_host._context.has("status_effect_entries"),
			"host context must be a minimal snapshot (bulk sentinel payload excluded)"
		)
		_expect(
			not attached_host._context.has("boss_pos"),
			"host context must exclude unrelated top-level keys"
		)
	actor_renderer._sync_odins_eye_overlay_host(
		canvas,
		{"odins_eye_context": {}},
		Vector2.ZERO,
		Vector2(155.0, 50.0),
		Vector2.ZERO
	)
	if attached_host != null:
		_expect(not bool(attached_host.get_debug_status().get("active", true)), "actor integration should explicitly hide the host when the overlay ends")
	canvas.queue_free()

	# [P1 본체 렌더 실도달 씰] 변신 몸체는 stage1 플레이어 드로우 경로에서
	# 일반 스프라이트를 대체해야 한다(혼딸기 스와프 형제). draw()는 headless
	# NOTIFICATION_DRAW 제약으로 직접 실행 불가 — 리포 표준(소스씰=함수본문
	# 검사, stage1_actor_render_budget_smoke 선례)으로 배선 순서를 봉인하고,
	# 스와프 판정은 유닛으로 봉인한다.
	var swap_renderer: Object = Stage1PlayerActorRenderer.new()
	_expect(
		swap_renderer.odins_eye_presentation_renderer != null
		and swap_renderer.odins_eye_presentation_renderer.has_method("draw_player"),
		"stage1 renderer must own a live Odin presentation renderer instance"
	)
	_expect(
		swap_renderer._is_odins_eye_body_swap_active({"transformed": true}),
		"transformed → body swap active"
	)
	_expect(
		swap_renderer._is_odins_eye_body_swap_active({"revival_animation_active": true}),
		"revival cinematic → body swap active (normal sprite hidden, cinematic owns reveal)"
	)
	_expect(
		swap_renderer._is_odins_eye_body_swap_active({"death_animation_active": true}),
		"death cinematic → body swap active"
	)
	_expect(
		not swap_renderer._is_odins_eye_body_swap_active({}),
		"empty context → no body swap"
	)
	_expect(
		not swap_renderer._is_odins_eye_body_swap_active({"afterimage": {"afterimages": [{}]}}),
		"afterimage payload alone → no body swap (overlay host territory)"
	)
	# 소스씰은 파일 전체가 아니라 draw() 함수 본문만 검사한다 — 다른 함수에
	# 남은 sprite_renderer.draw() 참조가 순서 검사를 오염시키지 못하게.
	var player_actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	var draw_body: String = SourceContractFunctionBody.extract(player_actor_source, "func draw(")
	_expect(not draw_body.is_empty(), "stage1 renderer draw() body must be extractable")
	var swap_branch_index: int = draw_body.find("if odins_eye_body_active:")
	var horn_branch_index: int = draw_body.find("elif horn_strawberry_transformed:")
	var sprite_draw_index: int = draw_body.find("sprite_renderer.draw(")
	var swap_call_index: int = draw_body.find("odins_eye_presentation_renderer.draw_player(")
	_expect(swap_branch_index >= 0, "draw() body must branch on odins_eye_body_active")
	_expect(swap_call_index >= 0, "draw() body must call odins_eye_presentation_renderer.draw_player")
	_expect(
		draw_body.find("odins_eye_presentation_renderer.draw_player(\n\t\t\tcanvas,\n\t\t\tcontext,") >= 0,
		"draw_player must receive the FULL actor context (not the odins sub-context)"
	)
	_expect(
		swap_branch_index >= 0 and horn_branch_index > swap_branch_index,
		"Odin body swap must take precedence before the horn strawberry branch"
	)
	_expect(
		swap_branch_index >= 0 and sprite_draw_index > swap_branch_index,
		"Odin body swap must replace (precede) the normal sprite_renderer draw"
	)
	_expect(
		draw_body.find("not horn_strawberry_transformed and not horn_strawberry_event_playing and not odins_eye_body_active") >= 0,
		"commando weapon overlays must skip while the Odin body owns the paddle"
	)
	_verify_porcelain_parser_contract()
	if _failures.is_empty():
		print("odins_eye_presentation_fx_host_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# 픽셀 QA 하니스의 dirty 귀속 porcelain 파서 유닛 씰. 하니스는 게이트
# 밖(비-headless 전용)이라 파서 회귀는 여기(게이트 등재 스모크)에서 봉인한다.
# 케이스: ①선행 공백 상태 열(" M"=unstaged) 보존 — 전체 strip_edges는 첫
# 행의 열을 한 칸씩 밀었다 ②rename old->new 분해(new가 해시 대상) ③따옴표
# +octal 경로 rename ④경로 안 리터럴 " -> "는 따옴표가 모호성 제거 ⑤CR 꼬리.
func _verify_porcelain_parser_contract() -> void:
	var unstaged: Dictionary = OdinPixelQaHarness.parse_porcelain_line(" M godot/scripts/a.gd")
	_expect(str(unstaged.get("status", "")) == " M", "porcelain: 선행 공백 상태 열(unstaged M) 보존")
	_expect(str(unstaged.get("path", "")) == "godot/scripts/a.gd", "porcelain: unstaged 경로 시작 문자 미훼손")
	var staged: Dictionary = OdinPixelQaHarness.parse_porcelain_line("M  godot/scripts/b.gd")
	_expect(str(staged.get("status", "")) == "M " and str(staged.get("path", "")) == "godot/scripts/b.gd", "porcelain: staged M 행 파싱")
	var renamed: Dictionary = OdinPixelQaHarness.parse_porcelain_line("R  old/name.gd -> new/name.gd")
	_expect(str(renamed.get("status", "")) == "R ", "porcelain: rename 상태 코드")
	_expect(str(renamed.get("path", "")) == "new/name.gd", "porcelain: rename은 NEW 경로가 해시 대상")
	_expect(str(renamed.get("old_path", "")) == "old/name.gd", "porcelain: rename old 경로 보존")
	var quoted_rename: Dictionary = OdinPixelQaHarness.parse_porcelain_line("R  \"old dir/\\355\\232\\214.gd\" -> \"new dir/b.gd\"")
	_expect(str(quoted_rename.get("path", "")) == "new dir/b.gd", "porcelain: 따옴표 rename new 경로 언이스케이프")
	_expect(str(quoted_rename.get("old_path", "")) == "old dir/회.gd", "porcelain: 따옴표+octal old 경로 복원")
	var arrow_in_path: Dictionary = OdinPixelQaHarness.parse_porcelain_line("R  \"weird -> name.gd\" -> plain.gd")
	_expect(
		str(arrow_in_path.get("old_path", "")) == "weird -> name.gd" and str(arrow_in_path.get("path", "")) == "plain.gd",
		"porcelain: 경로 안 리터럴 화살표는 따옴표가 모호성 제거"
	)
	var copied: Dictionary = OdinPixelQaHarness.parse_porcelain_line("C  src.gd -> copy.gd")
	_expect(str(copied.get("path", "")) == "copy.gd" and str(copied.get("old_path", "")) == "src.gd", "porcelain: copy도 new 경로가 해시 대상")
	# rename/copy는 Y열(워크트리 측)에도 온다 — X열만 보면 " R"/"MR"의
	# old -> new 전체가 단일 경로로 취급돼 deleted 오판+새 내용 미해시.
	var worktree_rename: Dictionary = OdinPixelQaHarness.parse_porcelain_line(" R old/w.gd -> new/w.gd")
	_expect(
		str(worktree_rename.get("status", "")) == " R" and str(worktree_rename.get("path", "")) == "new/w.gd" and str(worktree_rename.get("old_path", "")) == "old/w.gd",
		"porcelain: Y열(워크트리) rename도 new 경로가 해시 대상"
	)
	var worktree_copy: Dictionary = OdinPixelQaHarness.parse_porcelain_line(" C src/w.gd -> copy/w.gd")
	_expect(
		str(worktree_copy.get("path", "")) == "copy/w.gd" and str(worktree_copy.get("old_path", "")) == "src/w.gd",
		"porcelain: Y열 copy 분해"
	)
	var mixed_rename: Dictionary = OdinPixelQaHarness.parse_porcelain_line("MR old/m.gd -> new/m.gd")
	_expect(
		str(mixed_rename.get("status", "")) == "MR" and str(mixed_rename.get("path", "")) == "new/m.gd" and str(mixed_rename.get("old_path", "")) == "old/m.gd",
		"porcelain: 혼합 상태(MR) rename 분해"
	)
	var cr_tail: Dictionary = OdinPixelQaHarness.parse_porcelain_line("?? assets/x.png\r")
	_expect(str(cr_tail.get("path", "")) == "assets/x.png", "porcelain: CR 꼬리 제거")
	_expect(OdinPixelQaHarness.parse_porcelain_line("x").is_empty(), "porcelain: 형식 미달 행은 빈 결과")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
