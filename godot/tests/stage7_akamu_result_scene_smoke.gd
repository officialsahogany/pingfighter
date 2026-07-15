extends SceneTree

# Stage 7 아카무 결과화면 — 실제 stage_clear_result.tscn 전체 경로 봉인.
# 동기 status 합성만 보는 레그와 달리 실 프레임을 돌려 _draw fanout까지
# 검증한다: configure → draw(프레임 경과) → 씬 필드 click rect 착지 →
# one-shot 마지막 프레임 유지 → 클릭 입력 소비/펄스 → sheetless 상태에서
# status click rect 공백 + 입력 거부(폴백은 클릭을 광고하지 않는 계약).

const RESULT_SCENE := preload("res://scenes/stage_clear_result.tscn")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultUpdateSceneHandler := preload("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
const StageClearResultInputSceneHandler := preload("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
const StageClearResultStatusSceneHandler := preload("res://scripts/ui/stage_clear_result_status_scene_handler.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_real_scene_full_route()

	if _failures.is_empty():
		print("stage7_akamu_result_scene_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_real_scene_full_route() -> void:
	var scene: Control = RESULT_SCENE.instantiate() as Control
	_expect(scene != null, "stage clear result scene should instantiate for Stage 7 Akamu")
	root.add_child(scene)
	StageClearResultConfigSceneHandler.configure(
		scene,
		{
			"player_score": 5,
			"boss_score": 0,
			"current_stage": 7,
			"reward_plan": {
				"summary": "",
				"boxes": [{"kind": "normal"}],
				"reward_count": 1,
			},
		},
		Callable()
	)

	# 실 draw 통과: 프레임을 돌려 _draw가 실행되고 presenter의 click-rect
	# fanout이 씬 필드에 실제로 착지해야 한다(합성 status 기본값이 아니라).
	scene.queue_redraw()
	await process_frame
	await process_frame
	var scene_click_rect: Variant = scene.get(&"_stage7_boss_defeat_click_rect")
	_expect(scene_click_rect is Rect2 and (scene_click_rect as Rect2).size.x > 0.0, "Real draw must fan the Stage 7 click rect out to the scene field")

	var status: Dictionary = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(bool(status.get("stage7_boss_defeat_active", false)), "Stage 7 result should activate the Akamu defeat actor")
	_expect(bool(status.get("stage7_boss_defeat_sheet_loaded", false)), "Stage 7 result should load the Akamu defeat sheet")
	var status_click_rect: Rect2 = status.get("stage7_boss_defeat_click_rect", Rect2())
	_expect(status_click_rect == (scene_click_rect as Rect2), "Status click rect should be the drawn scene rect, not a synthesized default")

	# One-shot 계약: 시트 재생이 끝난 뒤(0.8s+)에도 마지막 프레임(7) 유지.
	StageClearResultUpdateSceneHandler.update_result_scene(scene, 1.60)
	scene.queue_redraw()
	await process_frame
	status = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(int(status.get("stage7_boss_defeat_base_frame", -1)) == 7, "Stage 7 Akamu must hold the final defeat frame after real draw + update")

	# 실입력: 공유 rect 클릭 → 소비 + 펄스 시작(transition base = 유지 프레임 7).
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = status_click_rect.get_center()
	_expect(StageClearResultInputSceneHandler.handle_result_input(scene, click, StageClearResultScene.DALJI_CLICK_DIALOGUE_DURATION), "Stage 7 click inside the drawn rect should be consumed")
	status = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(bool(status.get("stage7_boss_defeat_click_reaction_active", false)), "Stage 7 click should start the pulse reaction")
	_expect(int(status.get("stage7_boss_defeat_click_transition_base_frame", -1)) == 7, "Stage 7 click should freeze the held final frame")

	# 펄스 종료 후에도 마지막 프레임 유지.
	StageClearResultUpdateSceneHandler.update_result_scene(scene, 1.0)
	status = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(not bool(status.get("stage7_boss_defeat_click_reaction_active", true)), "Stage 7 click pulse should settle")
	_expect(int(status.get("stage7_boss_defeat_base_frame", -1)) == 7, "Stage 7 must still hold the final frame after the pulse")

	# Sheetless(코드 네이티브 폴백) 계약: status는 클릭 rect를 되살리지 않고
	# 실입력은 거부한다. (update/draw 없이 검증 — 실씬 draw 경로는 시트를
	# 즉시 재로드하므로, 완전한 sheetless 렌더 검증은 파일 토글 픽셀 QA 몫.)
	scene.set(&"_stage7_boss_defeat_sheet", null)
	scene.set(&"_stage7_boss_defeat_click_rect", Rect2())
	status = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(not bool(status.get("stage7_boss_defeat_sheet_loaded", true)), "Sheetless probe should read as not loaded")
	var sheetless_rect: Rect2 = status.get("stage7_boss_defeat_click_rect", Rect2(0.0, 0.0, 1.0, 1.0))
	_expect(sheetless_rect == Rect2(), "Sheetless Stage 7 status must not resurrect a clickable rect (code-native fallback advertises no click)")
	var sheetless_click := InputEventMouseButton.new()
	sheetless_click.button_index = MOUSE_BUTTON_LEFT
	sheetless_click.pressed = true
	sheetless_click.position = status_click_rect.get_center()
	var sheetless_before: Dictionary = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	StageClearResultInputSceneHandler.handle_result_input(scene, sheetless_click, StageClearResultScene.DALJI_CLICK_DIALOGUE_DURATION)
	var sheetless_after: Dictionary = StageClearResultStatusSceneHandler.get_interaction_status(scene, StageClearResultScene.DALJI_CLICK_DIALOGUE)
	_expect(
		not bool(sheetless_after.get("stage7_boss_defeat_click_reaction_active", false))
		and float(sheetless_after.get("stage7_boss_defeat_click_reaction_timer", 0.0)) >= float(sheetless_before.get("stage7_boss_defeat_click_reaction_timer", 0.0)),
		"Sheetless Stage 7 click must not start a defeat-actor reaction (real input rejects it)"
	)

	scene.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
