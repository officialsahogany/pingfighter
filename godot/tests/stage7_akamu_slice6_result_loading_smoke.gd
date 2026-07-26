extends SceneTree

const BattleLoadingScreenRenderer := preload("res://scripts/core/battle_loading_screen_renderer.gd")
const StageClearResultActorClickHandler := preload("res://scripts/ui/stage_clear_result_actor_click_handler.gd")
const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultActorPresenter := preload("res://scripts/ui/stage_clear_result_actor_presenter.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultSceneScript := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultSceneShellPrewarmState := preload("res://scripts/core/stage_clear_result_scene_shell_prewarm_state.gd")

var _failures: Array[String] = []


class StageOwnerProbe:
	extends RefCounted

	var current_stage := 7


class DrawProbe:
	extends Node2D

	var draw_callback: Callable = Callable()
	var draw_result: Dictionary = {}
	var draw_calls: int = 0

	func _draw() -> void:
		draw_calls += 1
		if draw_callback.is_valid():
			draw_result = draw_callback.call(self)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_loading_route()
	_verify_result_asset_contract()
	_verify_scene_texture_field_fanout()
	_verify_click_input_route()
	_verify_one_shot_defeat_hold()
	_verify_result_shell_fallback_readiness()
	await _verify_code_native_result_draw()

	if _failures.is_empty():
		print("stage7_akamu_slice6_result_loading_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_loading_route() -> void:
	# Stage 7 loading contract: the Akamu prebattle intro video owns the loading
	# spectacle, so the renderer must carry NO stage7 stained-glass wiring at all.
	# Loading textures that the reveal gate can never display is build-then-discard
	# (and putting 7 back into the gate deadlocks the video handoff — sealed by
	# stage7_akamu_prebattle_live_frame_smoke).
	var renderer_constants: Dictionary = (BattleLoadingScreenRenderer as GDScript).get_script_constant_map()
	_expect(not renderer_constants.has("STAGE7_STAINED_GLASS_FULLCOLOR_PATH"), "Stage 7 loading must not re-introduce dead stained-glass fullcolor wiring (the intro video owns the loading spectacle)")
	_expect(not renderer_constants.has("STAGE7_STAINED_GLASS_REVEAL_MASK_PATH"), "Stage 7 loading must not re-introduce dead stained-glass mask wiring (the intro video owns the loading spectacle)")
	var renderer := BattleLoadingScreenRenderer.new()
	renderer.prewarm_stage_assets(7)
	_expect(renderer.get("stage6_stained_glass_texture") == null, "Stage 7 loading prewarm must not load Stage 6 art as the actor identity")
	var stage7_owner := StageOwnerProbe.new()
	_expect(not renderer.should_hold_completion(stage7_owner, Callable()), "Stage 7 loading must stay OUT of the completion hold (the prebattle intro video owns the loading spectacle; the hold would deadlock the video handoff)")


func _verify_result_asset_contract() -> void:
	var config: Dictionary = StageClearResultAssetLoader.get_default_result_asset_path_config()
	_expect(str(config.get("stage7_background_texture", "")) == StageClearResultAssetLoader.STAGE7_BACKGROUND_PATH, "Stage 7 result should own a dedicated background path")
	_expect(str(config.get("stage7_boss_defeat_sheet", "")) == StageClearResultAssetLoader.STAGE7_BOSS_DEFEAT_SHEET_PATH, "Stage 7 result should own the AutoSprite defeat-sheet path")
	_expect(StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_FRAME_COUNT == 8, "Stage 7 result sheet should expose eight frames")
	_expect(StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_GRID_COLS == 4, "Stage 7 result sheet should expose a 4x2 grid")
	_expect(StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_CELL_SIZE == Vector2(256.0, 256.0), "Stage 7 result sheet should expose 256px cells")
	var paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 7)
	var dedicated_sheet_ready := ResourceLoader.exists(StageClearResultAssetLoader.STAGE7_BOSS_DEFEAT_SHEET_PATH)
	_expect(str(paths.get("stage7_boss_defeat_sheet", "")) == (StageClearResultAssetLoader.STAGE7_BOSS_DEFEAT_SHEET_PATH if dedicated_sheet_ready else ""), "Stage 7 result loader should automatically promote the defeat sheet when it arrives")
	if dedicated_sheet_ready:
		var textures: Dictionary = StageClearResultAssetLoader.load_textures({}, paths)
		var sheet := textures.get("stage7_boss_defeat_sheet", null) as Texture2D
		_expect(sheet != null and sheet.get_size() == Vector2(1024.0, 512.0), "Stage 7 promoted defeat sheet should match the 1024x512 AutoSprite contract")


func _verify_scene_texture_field_fanout() -> void:
	# Structural seal for the unknown-field payload guard: every asset-loader
	# texture key must have a matching `_<key>` field on the REAL result scene,
	# or StageClearResultSceneFieldApplier rejects the payload with a runtime
	# push_error on every apply (the stage7 regression class).
	var scene_script: Script = StageClearResultSceneScript
	var scene_field_names: Dictionary = {}
	for property in scene_script.get_script_property_list():
		scene_field_names[str(property.get("name", ""))] = true
	for texture_key in StageClearResultAssetLoader.TEXTURE_KEYS:
		_expect(scene_field_names.has("_%s" % texture_key), "Result scene must declare the '_%s' field for asset-loader texture key '%s' (unknown payload keys are rejected at apply time)" % [texture_key, texture_key])
	for stage7_field in ["_stage7_boss_defeat_click_rect", "_stage7_boss_defeat_click_reaction_timer", "_stage7_boss_defeat_click_transition_base_frame"]:
		_expect(scene_field_names.has(stage7_field), "Result scene must declare '%s' for the Stage 7 click-reaction wiring" % stage7_field)


func _verify_click_input_route() -> void:
	# The presenter's returned click rect must be reachable from the real input
	# path: the scene click config must name scene fields, and a click inside
	# the shared rect must produce a handled attempt.
	var click_config: Dictionary = StageClearResultActorClickHandler.get_boss_result_click_config(7)
	_expect(str(click_config.get("sheet_property", "")) == "_stage7_boss_defeat_sheet", "Stage 7 click config should read the scene defeat-sheet field")
	_expect(str(click_config.get("reaction_timer_property", "")) == "_stage7_boss_defeat_click_reaction_timer", "Stage 7 click config should read the scene reaction-timer field")
	var fallback_click_config: Dictionary = StageClearResultActorClickHandler.get_stage_result_fallback_click_config(7)
	_expect(not fallback_click_config.is_empty(), "Stage 7 must participate in the stage-result fallback click route")
	var view_size := Vector2(1280.0, 720.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, 1.0)
	var click_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		7,
		true,
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		1.0
	)
	_expect(bool(click_result.get("handled", false)), "Stage 7 click inside the shared result rect should be handled by the real input route")
	var outside_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		7,
		true,
		Vector2(2.0, 2.0),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		1.0
	)
	_expect(not bool(outside_result.get("handled", false)), "Stage 7 click outside the shared result rect should not be handled")
	# Real input contract: with no defeat sheet loaded (code-native fallback),
	# the scene apply handler refuses clicks — the fallback must not advertise
	# a clickable rect it cannot honor.
	var sheetless_result: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		7,
		false,
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		1.0
	)
	_expect(not bool(sheetless_result.get("handled", false)), "Stage 7 click must not be handled while the defeat sheet is absent (code-native fallback is not clickable)")


func _verify_one_shot_defeat_hold() -> void:
	# 권위 manifest 계약: defeat.loop = false — 아카무는 쓰러진 뒤 마지막
	# 프레임(7)을 유지해야 하며, stage6식 % 순환으로 다시 일어나면 안 된다.
	for probe in [[0.0, 0], [0.35, 3], [0.79, 7], [0.81, 7], [1.61, 7]]:
		var state: Dictionary = StageClearResultActorDrawHelper.get_stage7_akamu_reaction_state(
			float(probe[0]),
			StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
			0
		)
		_expect(int(state.get("base_frame", -1)) == int(probe[1]), "Stage 7 defeat sheet must be one-shot: t=%.2fs should hold frame %d, got %d" % [float(probe[0]), int(probe[1]), int(state.get("base_frame", -1))])
	# 클릭 시작 시 저장되는 transition base frame도 같은 clamp를 써야 한다.
	var view_size := Vector2(1280.0, 720.0)
	var click_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, 1.0)
	var late_click: Dictionary = StageClearResultActorClickHandler.handle_boss_defeat_click(
		7,
		true,
		click_rect.get_center(),
		view_size,
		1.0,
		StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		1.61
	)
	_expect(int(late_click.get("transition_base_frame", -1)) == 7, "Stage 7 click at t=1.61s must record the held last frame (7) as the transition base frame")


func _verify_result_shell_fallback_readiness() -> void:
	var prewarm := StageClearResultSceneShellPrewarmState.new()
	var keys: Array[String] = prewarm.get_required_scene_asset_keys(7)
	_expect(not keys.has("background_texture"), "Stage 7 result spawn should permit the generic background until dedicated art lands")
	_expect(not keys.has("stage7_boss_defeat_sheet"), "Stage 7 result spawn should permit the code-native actor until the optional sheet lands")
	_expect(keys.has("player_victory_sheet") and keys.has("result_box_fx"), "Stage 7 result spawn should retain shared presentation readiness gates")


func _verify_code_native_result_draw() -> void:
	var probe := DrawProbe.new()
	probe.draw_callback = Callable(self, "_draw_stage7_probe")
	root.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var expected_rect: Rect2 = StageClearResultLayoutHelper.get_stage7_result_draw_rect(Vector2(1280.0, 720.0), 1.0)
	_expect(probe.draw_calls > 0, "Stage 7 code-native result actor should execute inside the canvas draw lifecycle")
	_expect(probe.draw_result.get("stage7_boss_defeat_rect", Rect2()) == expected_rect, "Stage 7 code-native result actor should draw inside the shared result rect")
	_expect(not probe.draw_result.has("stage7_boss_defeat_click_rect"), "Stage 7 code-native fallback must not advertise a click rect (real input rejects sheetless clicks)")
	probe.queue_free()
	await process_frame


func _draw_stage7_probe(canvas: CanvasItem) -> Dictionary:
	return StageClearResultActorPresenter.draw_defeated_boss(
		canvas,
		Vector2(1280.0, 720.0),
		1.0,
		{
			"current_stage": 7,
			"timer": 0.25,
			"stage7_boss_defeat_sheet": null,
			"stage7_boss_defeat_click_reaction_timer": StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
			"stage7_boss_defeat_click_transition_base_frame": 0,
		}
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
