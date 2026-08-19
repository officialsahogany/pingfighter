extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const CaptureOverlay := preload("res://tools/tower_audition_capture_overlay.gd")
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const OUTPUT_DIR := "res://.godot/codex_captures/tower_audition"
const TRANSITION_TIMEOUT_FRAMES := 3600
const PHASE_TIMEOUT_FRAMES := 900
const EXPECTED_GATE_FLOORS: Array[int] = [1, 2, 3, 4, 5, 6, 7]

var _main_node: Node = null
var _gameplay_modules: Object = null
var _flow: Object = null
var _flow_driver: Object = null
var _event_driver: Object = null
var _loot: Object = null
var _encounters: Array[Dictionary] = []
var _gate_floors: Array[int] = []
var _capture_paths: Dictionary = {}
var _record_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower audition live QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower audition live QA requires Vulkan")
		return
	TowerAuditionBuildConfig.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var target_variant := _argument("--target-opening=", "gaksi")
	var startup_only := _has_argument("--startup-only")
	var registry := TowerAscentBossRegistry.new()
	var map_seed := _resolve_seed_for_variant(registry, target_variant)
	if map_seed <= 0:
		_fail("could not resolve a deterministic seed for opening variant %s" % target_variant)
		return
	if not _prepare_selection_state(map_seed):
		_fail("GameSelectionState was unavailable")
		return
	_main_node = MainScene.instantiate()
	get_root().add_child(_main_node)
	await _frames(16)
	_prepare_battle_scene()
	_gameplay_modules = _main_node.get("gameplay_modules")
	_flow = _get_module("tower_ascent_flow_owner")
	_flow_driver = _get_module("battle_scene_match_flow_driver")
	_event_driver = _get_module("battle_scene_match_event_driver")
	_loot = _get_module("victory_loot_phase_state")
	if _gameplay_modules == null or _flow == null or _flow_driver == null or _event_driver == null or _loot == null:
		_fail("production tower modules were unavailable")
		return
	_record_path = "user://tower_audition_live_qa_%d.cfg" % Time.get_ticks_usec()
	_flow.set_record_store_path_for_tests(_record_path)
	var seeded_slots := registry.get_seeded_floor_slots(1, map_seed)
	if seeded_slots.is_empty():
		_fail("seeded opening pool was empty")
		return
	var opening_slot: Dictionary = seeded_slots[0]
	var opening_variant := str(opening_slot.get("variant", "dalji"))
	var opening_encounter := registry.resolve_battle_encounter(
		str(opening_slot.get("slot_id", ""))
	)
	_unfreeze_battle_updates()
	_flow_driver.call(
		"_finish_tower_boss_route",
		opening_encounter,
		_gameplay_modules,
		_main_node,
		Callable()
	)
	if not bool(_event_driver.is_stage_transition_loading_active()):
		_fail("opening boss did not enter the production battle transition")
		return
	if not await _wait_for_battle_transition():
		return
	_prepare_battle_scene()
	var live_variant := str(_main_node.get("stage1_boss_variant"))
	if int(_main_node.get("current_stage")) != 1 or live_variant != opening_variant:
		_fail("live opening variant mismatch: expected=%s actual=%s" % [opening_variant, live_variant])
		return
	print("[TowerAuditionLiveQA] startup seed=%d target=%s slot=%s live_variant=%s" % [
		map_seed,
		target_variant,
		str(opening_slot.get("slot_id", "")),
		live_variant,
	])
	if startup_only:
		print("tower_audition_live_qa: startup_ok seed=%d variant=%s" % [map_seed, live_variant])
		await _shutdown(0)
		return
	DisplayServer.window_set_title("Tower Audition Live 1-7 QA")
	var combat_count := 0
	while combat_count < 16:
		if not await _clear_current_combat():
			return
		combat_count += 1
		var phase_name := str(_flow.get_phase_name())
		if phase_name == "FAKE_ENDING_TEASER":
			_send_confirm_to_flow()
			await _frames(4)
			if str(_flow.get_phase_name()) != "RUN_SETTLEMENT":
				_fail("floor-7 standard clear did not enter the existing settlement")
				return
			if not await _capture("floor_07_clear_settlement"):
				return
			break
		if phase_name == "ENDING_CHOICE":
			_fail("fresh audition record unexpectedly entered repeat-clear choice")
			return
		if not await _advance_until_next_combat(combat_count):
			return
	if str(_flow.get_phase_name()) != "RUN_SETTLEMENT":
		_fail("live traversal did not finish at floor-7 settlement")
		return
	if _gate_floors != EXPECTED_GATE_FLOORS:
		_fail("gate-floor traversal mismatch: %s" % str(_gate_floors))
		return
	var settlement: Dictionary = _flow.get_settlement_state_snapshot()
	if int(settlement.get("floor", 0)) != 7:
		_fail("settlement floor mismatch: %s" % str(settlement))
		return
	var record: Dictionary = _flow.get_record_snapshot()
	if int(record.get("highest_floor", 0)) != 7:
		_fail("record floor mismatch: %s" % str(record))
		return
	if not _capture_paths.has("floor_01_choice_map"):
		_fail("floor-1 choice-map capture was not produced")
		return
	if not _capture_paths.has("floor_04_to_07_battle"):
		_fail("floor-4-to-7 battle capture was not produced")
		return
	var evidence := {
		"map_seed": map_seed,
		"opening_variant": live_variant,
		"encounters": _encounters,
		"gate_floors": _gate_floors,
		"settlement": settlement,
		"record": record,
		"captures": _capture_paths,
	}
	var evidence_path := ProjectSettings.globalize_path(OUTPUT_DIR).path_join(
		"tower_audition_live_evidence.json"
	)
	var evidence_file := FileAccess.open(evidence_path, FileAccess.WRITE)
	if evidence_file == null:
		_fail("could not create live evidence json")
		return
	evidence_file.store_string(JSON.stringify(evidence, "  "))
	evidence_file.close()
	print("[TowerAuditionLiveQA] encounters=%s" % JSON.stringify(_encounters))
	print("[TowerAuditionLiveQA] captures=%s" % JSON.stringify(_capture_paths))
	print("[TowerAuditionLiveQA] evidence=%s" % evidence_path)
	print("tower_audition_live_qa: full_run_ok combats=%d gate_floors=%s blocked_shells=0" % [
		combat_count,
		str(_gate_floors),
	])
	await _shutdown(0)


func _clear_current_combat() -> bool:
	_prepare_battle_scene()
	var score_state: Object = _get_module("match_score_state")
	var scoreboard_state: Object = _get_module("scoreboard_state")
	if score_state == null or scoreboard_state == null:
		_fail("production score states were unavailable")
		return false
	if score_state.has_method("force_score"):
		score_state.force_score(MatchScoreState.WIN_GOAL, 0)
	else:
		score_state.set("player_score", MatchScoreState.WIN_GOAL)
		score_state.set("boss_score", 0)
		score_state.set("deuce_mode", false)
	scoreboard_state.start(MatchScoreState.WIN_GOAL, 0, true, "player")
	if not bool(_flow_driver.start_debug_tower_reward_pick(
		_main_node,
		_gameplay_modules,
		Callable()
	)):
		_fail("F9 production reward path rejected the current combat")
		return false
	await _frames(3)
	var risk: Dictionary = _flow.get_current_node_risk_context()
	var slot_id := str(risk.get("boss_slot_id", ""))
	var encounter := TowerAscentBossRegistry.new().resolve_battle_encounter(slot_id)
	if slot_id.is_empty() or encounter.is_empty():
		_fail("current combat had no routable encounter: %s" % str(risk))
		return false
	if bool(encounter.get("fallback_used", true)) or str(encounter.get("source_status", "")) != TowerAscentBossRegistry.STATUS_PORTED:
		_fail("shell or stand-in reached live combat: %s" % str(encounter))
		return false
	var floor_number := int(risk.get("floor", 0))
	if bool(risk.get("is_gatekeeper", false)) and not _gate_floors.has(floor_number):
		_gate_floors.append(floor_number)
	_encounters.append({
		"floor": floor_number,
		"gatekeeper": bool(risk.get("is_gatekeeper", false)),
		"slot_id": slot_id,
		"stage": int(encounter.get("stage", 0)),
		"boss_id": str(encounter.get("boss_id", "")),
		"variant": str(encounter.get("variant", "")),
		"source_status": str(encounter.get("source_status", "")),
	})
	print("[TowerAuditionLiveQA] combat_clear floor=%d gate=%s slot=%s stage=%d variant=%s" % [
		floor_number,
		str(bool(risk.get("is_gatekeeper", false))),
		slot_id,
		int(encounter.get("stage", 0)),
		str(encounter.get("variant", "")),
	])
	var reward_state: Object = _loot.get("_reward_pick_state")
	if reward_state == null or not reward_state.has_method("_finish"):
		_fail("production reward-pick state was unavailable")
		return false
	reward_state.call("_finish")
	await _frames(4)
	return true


func _advance_until_next_combat(combat_count: int) -> bool:
	var steps := 0
	while steps < 40:
		steps += 1
		var phase_name := str(_flow.get_phase_name())
		print("[TowerAuditionLiveQA] route_step=%d phase=%s node=%s active=%s" % [
			steps,
			phase_name,
			str(_flow.get_current_node_id()),
			str(bool(_flow.is_active())),
		])
		if phase_name == "ROUTE_AIM":
			if combat_count == 1 and not _capture_paths.has("floor_01_choice_map"):
				if not await _capture("floor_01_choice_map"):
					return false
			var target_index := _preferred_target_index()
			if target_index < 0:
				_fail("route aim exposed no selectable target")
				return false
			_flow.debug_launch_at_target(target_index)
			var round_state: Object = _get_module("round_flow_state")
			if round_state != null and round_state.has_method("begin_serve"):
				round_state.begin_serve(Time.get_ticks_msec())
			if not await _wait_for_phase_change("ROUTE_AIM"):
				return false
			continue
		if phase_name == "MAP_TRANSITION":
			_flow.update_selective(10.0, _main_node)
			await _frames(3)
			continue
		if phase_name == "NODE_MODAL":
			_flow.debug_advance_to_route_aim()
			await _frames(2)
			continue
		if phase_name in ["FAKE_ENDING_TEASER", "ENDING_CHOICE", "RUN_SETTLEMENT"]:
			return true
		if not bool(_flow.is_active()):
			_unfreeze_battle_updates()
			if not await _wait_for_battle_transition():
				return false
			_prepare_battle_scene()
			var actual_stage := int(_main_node.get("current_stage"))
			if actual_stage >= 4 and actual_stage <= 7 and not _capture_paths.has("floor_04_to_07_battle"):
				if not await _capture("floor_04_to_07_battle"):
					return false
			return true
		await _frames(2)
	_fail("route traversal exceeded the node-step limit")
	return false


func _preferred_target_index() -> int:
	var targets: Array = _flow.get_route_aim_targets()
	if targets.is_empty():
		return -1
	for index in range(targets.size()):
		var target := targets[index] as Dictionary
		if str(target.get("kind", "")) not in ["boss", "combat", "enraged"]:
			return index
	return 0


func _wait_for_phase_change(previous_phase: String) -> bool:
	for _frame in range(PHASE_TIMEOUT_FRAMES):
		_flow.update_selective(1.0 / 60.0, _main_node)
		if str(_flow.get_phase_name()) != previous_phase:
			return true
		await process_frame
	_fail("phase timed out: %s" % previous_phase)
	return false


func _wait_for_battle_transition() -> bool:
	var frames := 0
	while bool(_event_driver.is_stage_transition_loading_active()) and frames < TRANSITION_TIMEOUT_FRAMES:
		await process_frame
		frames += 1
	if bool(_event_driver.is_stage_transition_loading_active()):
		_fail("production battle transition timed out")
		return false
	_freeze_battle_updates()
	await _frames(8)
	return true


func _capture(label: String) -> bool:
	var capture_overlay: Control = null
	if label != "floor_04_to_07_battle":
		capture_overlay = CaptureOverlay.new()
		get_root().add_child(capture_overlay)
		capture_overlay.configure(_flow)
		await _frames(3)
	await _frames(5)
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		if capture_overlay != null:
			capture_overlay.queue_free()
		_fail("capture was empty: %s" % label)
		return false
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		if capture_overlay != null:
			capture_overlay.queue_free()
		_fail("could not create capture directory")
		return false
	var output_path := output_dir.path_join("%s.png" % label)
	if image.save_png(output_path) != OK:
		if capture_overlay != null:
			capture_overlay.queue_free()
		_fail("could not save capture: %s" % output_path)
		return false
	if capture_overlay != null:
		capture_overlay.queue_free()
	_capture_paths[label] = output_path
	print("[TowerAuditionLiveQA] capture %s=%s" % [label, output_path])
	return true


func _send_confirm_to_flow() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	_flow.handle_input(event)


func _prepare_selection_state(map_seed: int) -> bool:
	var selection_state := get_root().get_node_or_null("GameSelectionState")
	if selection_state == null or not selection_state.has_method("set_stage"):
		return false
	selection_state.set_character({
		"id": "viper",
		"runtime_id": "viper",
		"name": "세린",
	})
	# The wrapper redirects APPDATA for this process, so the real Stage 1 startup
	# path can run without touching the player's canonical plaza save.
	selection_state.set_stage(1, "dalji", false, "")
	selection_state.set_league_mode("champion")
	selection_state.debug_set_tower_map_seed(map_seed)
	selection_state.request_skip_battle_logo_once()
	return true


func _prepare_battle_scene() -> void:
	if _main_node == null:
		return
	if _main_node.has_method("_initialize_battle"):
		_main_node.call("_initialize_battle", false)
	if _main_node.has_method("configure_player_character"):
		_main_node.call("configure_player_character", "viper")
	var warmup: Object = _get_module("battle_boot_warmup_controller")
	if warmup != null:
		warmup.set("boot_warmup_finished", true)
		warmup.set("boot_warmup_step", 999)
	var logo_intro: Object = _get_module("penguin_logo_intro")
	if logo_intro != null:
		logo_intro.set("active", false)
	var flow_controller: Object = _get_module("battle_scene_flow_controller")
	if flow_controller != null:
		flow_controller.set("_battle_initialized", true)
		flow_controller.set("_stage_landing_intro_started", true)
		flow_controller.set("_ball_spawn_intro_started", true)
	var landing_intro: Object = _get_module("stage_landing_intro")
	if landing_intro != null:
		landing_intro.set("active", false)
	var ball_spawn_intro: Object = _get_module("stage_ball_spawn_intro")
	if ball_spawn_intro != null:
		if ball_spawn_intro.has_method("reset"):
			ball_spawn_intro.reset()
		ball_spawn_intro.set("active", false)
		ball_spawn_intro.set("overlay_active", false)
	var round_state: Object = _get_module("round_flow_state")
	if round_state != null and round_state.has_method("begin_serve"):
		round_state.begin_serve(Time.get_ticks_msec())
	# Keep the QA ball parked while route transitions are advanced deterministically;
	# each encounter still enters through the production stage-transition owner.
	_main_node.set("ball_active", false)
	_main_node.set("waiting_for_serve", true)
	_main_node.set("boss_pos", Vector2(325.0, 25.0))
	_main_node.set("player_pos", Vector2(310.0, 650.0))
	_main_node.queue_redraw()
	_freeze_battle_updates()


func _freeze_battle_updates() -> void:
	if _main_node == null or not is_instance_valid(_main_node):
		return
	_main_node.set_process(false)
	_main_node.set_physics_process(false)


func _unfreeze_battle_updates() -> void:
	if _main_node == null or not is_instance_valid(_main_node):
		return
	_main_node.set_process(true)
	_main_node.set_physics_process(true)


func _resolve_seed_for_variant(registry: Object, target_variant: String) -> int:
	var normalized := target_variant.strip_edges().to_lower()
	for map_seed in range(1, 4097):
		var slots: Array[Dictionary] = registry.get_seeded_floor_slots(1, map_seed)
		if not slots.is_empty() and str(slots[0].get("variant", "dalji")) == normalized:
			return map_seed
	return 0


func _get_module(key: String) -> Object:
	if _main_node == null or not _main_node.has_method("_get_module"):
		return null
	var value: Variant = _main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _argument(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with(prefix):
			return value.trim_prefix(prefix).strip_edges().to_lower()
	return fallback


func _has_argument(expected: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if str(argument) == expected:
			return true
	return false


func _shutdown(exit_code: int) -> void:
	if not _record_path.is_empty():
		var absolute_record := ProjectSettings.globalize_path(_record_path)
		for path in [absolute_record, "%s.last_good.cfg" % absolute_record]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	if _gameplay_modules != null and _gameplay_modules.has_method("clear_all"):
		_gameplay_modules.clear_all()
	if _main_node != null and is_instance_valid(_main_node):
		_main_node.set_script(null)
		_main_node.queue_free()
	await _frames(3)
	quit(exit_code)


func _fail(message: String) -> void:
	print("[TowerAuditionLiveQA] FAILURE: %s" % message)
	push_error(message)
	call_deferred("_shutdown", 1)
