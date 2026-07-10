extends SceneTree

const BattleFrameFlowController := preload("res://scripts/core/battle_frame_flow_controller.gd")
const MythicItemAcquisitionCinematicRuntime := preload("res://scripts/items/mythic_item_acquisition_cinematic_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const ANGEL_PERK_ID := "angel_blessing"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cinematic_start_helper_propagates_false()
	_verify_false_cinematic_apply_result_is_ready_immediately()
	_verify_true_cinematic_apply_result_defers_choice_finish()
	_verify_round_boundary_resumes_deferred_choice_after_scoreboard()
	_verify_result_source_true_cinematic_wait_preserves_next_intro_policy()
	_verify_natural_cinematic_completion_notifies_once()
	_verify_frame_flow_rechecks_synchronously_opened_modals()
	_verify_round_boundary_releases_canceled_cinematic_wait()
	_finish()


func _verify_cinematic_start_helper_propagates_false() -> void:
	var owner := FakeOwner.new(3)
	root.add_child(owner)
	var start_runtime := FakeStartResultMythicRuntime.new(false)
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": FakeCatalog.new(),
		"mythic_item_runtime": start_runtime,
	})
	var started: bool = MythicPerkGrantHelper.try_start_acquisition_cinematic(
		"megingjord",
		owner,
		registry,
		Vector2(380.0, 375.0),
		Vector2.INF,
		_angel_choice()
	)
	_expect(start_runtime.start_calls == 1, "cinematic helper should call the runtime start seam once")
	_expect(not started, "cinematic helper must propagate a false runtime start result")
	owner.free()


func _verify_false_cinematic_apply_result_is_ready_immediately() -> void:
	var fixture: Dictionary = _build_runtime_fixture(2)
	var runtime: Object = fixture["runtime"]
	runtime.set("_choice_apply_flow", FakeAcceptedAngelApplyFlow.new(false))
	runtime.set("current_choice_context", {"source": "battle_debug_grant"})
	_expect(
		bool(runtime.apply_choice(_angel_choice(), fixture["owner"], fixture["registry"])),
		"cinematic=false apply-flow seam should still accept Angel"
	)
	var pending: Dictionary = _first_pending_roll(runtime)
	_expect(str(pending.get("policy", "")) == "current_stage", "cinematic=false battle grant should retain current-stage policy")
	_expect(not bool(pending.get("waiting_for_cinematic", true)), "try_start_acquisition_cinematic=false must not create a cinematic wait")
	_expect(bool(pending.get("ready", false)), "try_start_acquisition_cinematic=false reservation should be ready immediately")


func _verify_true_cinematic_apply_result_defers_choice_finish() -> void:
	var fixture: Dictionary = _build_runtime_fixture(3)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var catalog: Object = fixture["catalog"]
	var choice: Dictionary = _angel_choice()
	runtime.set("_choice_apply_flow", FakeAcceptedAngelApplyFlow.new())
	runtime.set("current_choice_context", {
		"source": "battle_mythic_jackpot",
		"grant_scope": "battle",
	})
	runtime.set("pending_skill_choices", 2)
	runtime.set("choice_active", true)

	_expect(bool(runtime.apply_choice(choice, owner, registry)), "cinematic=true apply-flow seam should accept Angel")
	_expect(runtime.get_runtime_skill_level(ANGEL_PERK_ID) == 1, "cinematic=true apply-flow seam should commit raw Angel level 0 -> 1")
	var pending_before_finish: Dictionary = _first_pending_roll(runtime)
	_expect(bool(pending_before_finish.get("waiting_for_cinematic", false)), "cinematic_started=true must reserve Angel with waiting_for_cinematic=true")
	_expect(not bool(pending_before_finish.get("ready", true)), "cinematic-waiting Angel reservation must not be ready early")

	var finish_value: Variant = runtime.call(
		"_finish_successful_choice",
		ANGEL_PERK_ID,
		owner,
		registry,
		null,
		choice
	)
	var finish_result: Dictionary = _as_dictionary(finish_value)
	_expect(bool(finish_result.get("accepted", false)), "Angel choice finish should complete its current transaction")
	_expect(not bool(finish_result.get("opened_next_choice", true)), "cinematic-waiting Angel must defer the remaining runtime choice")
	_expect(int(runtime.get("pending_skill_choices")) == 1, "deferred finish should consume only the selected Angel choice")
	_expect(not bool(runtime.get("choice_active")), "deferred next choice must remain closed under the acquisition cinematic")
	_expect(int(catalog.get("get_choices_calls")) == 0, "deferred finish must not synchronously build the next choice")
	_expect(str((runtime.get("current_choice_context") as Dictionary).get("source", "")) == "battle_mythic_jackpot", "deferred finish should preserve choice context for the later modal")
	_expect(bool(_first_pending_roll(runtime).get("waiting_for_cinematic", false)), "choice finish must not release the cinematic wait itself")

	var completion: Dictionary = runtime.on_angel_blessing_acquisition_cinematic_finished(
		ANGEL_PERK_ID,
		owner,
		registry
	)
	_expect(bool(completion.get("opened_next_choice", false)), "cinematic completion should open the deferred remaining choice")
	_expect(runtime.is_choice_active(), "remaining runtime choice must open before Angel")
	_expect(not runtime.is_angel_blessing_modal_active(), "Angel modal must remain closed while the remaining choice is active")
	_expect(int(catalog.get("get_choices_calls")) == 1, "cinematic completion should build the deferred choice exactly once")
	var released_pending: Dictionary = _first_pending_roll(runtime)
	_expect(not bool(released_pending.get("waiting_for_cinematic", true)), "cinematic completion should release the current-stage wait")
	_expect(bool(released_pending.get("ready", false)), "released current-stage reservation should remain ready behind the choice")

	var final_choice: Dictionary = {"id": "sentinel_next_choice", "name": "sentinel"}
	var final_finish: Dictionary = _as_dictionary(runtime.call(
		"_finish_successful_choice",
		"sentinel_next_choice",
		owner,
		registry,
		null,
		final_choice
	))
	_expect(bool(final_finish.get("accepted", false)), "final deferred choice should finish normally")
	_expect(int(runtime.get("pending_skill_choices")) == 0, "final deferred choice should consume the remaining transaction")
	_expect(not runtime.is_choice_active(), "final deferred choice should close before Angel opens")
	_expect(runtime.is_angel_blessing_modal_active(), "Angel should open only after the final deferred choice closes")


func _verify_round_boundary_resumes_deferred_choice_after_scoreboard() -> void:
	var fixture: Dictionary = _build_runtime_fixture(4)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var catalog: Object = fixture["catalog"]
	runtime.set("_choice_apply_flow", FakeAcceptedAngelApplyFlow.new(true))
	runtime.set("current_choice_context", {"source": "battle_mythic_jackpot"})
	runtime.set("pending_skill_choices", 2)
	runtime.set("choice_active", true)
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "round/scoreboard fixture should accept cinematic-waiting Angel")
	var first_finish: Dictionary = _as_dictionary(runtime.call(
		"_finish_successful_choice",
		ANGEL_PERK_ID,
		owner,
		registry,
		null,
		_angel_choice()
	))
	_expect(bool(first_finish.get("accepted", false)), "round/scoreboard fixture should finish the Angel choice")
	_expect(not runtime.is_choice_active() and int(runtime.get("pending_skill_choices")) == 1, "cinematic wait should bank one closed pending choice")

	runtime.on_angel_blessing_round_boundary()
	var released: Dictionary = _first_pending_roll(runtime)
	_expect(bool(released.get("ready", false)) and not bool(released.get("waiting_for_cinematic", true)), "round boundary should release the canceled cinematic wait")
	runtime.update_angel_blessing_acquisition(
		0.0,
		owner,
		registry,
		{"stage_clear_result_screen_active": true}
	)
	_expect(not runtime.is_choice_active(), "scoreboard blocker should keep the banked choice closed")
	_expect(not runtime.is_angel_blessing_modal_active(), "scoreboard blocker should keep Angel closed")

	runtime.update_angel_blessing_acquisition(0.0, owner, registry)
	_expect(runtime.is_choice_active(), "after scoreboard closes, update must reopen the banked choice before Angel")
	_expect(not runtime.is_angel_blessing_modal_active(), "scoreboard release must not skip the banked choice and open Angel")
	_expect(int(catalog.get("get_choices_calls")) == 1, "scoreboard release should build the banked choice exactly once instead of deadlocking")
	_expect(int(runtime.get("pending_skill_choices")) == 1, "reopening the banked choice must not consume it early")


func _verify_result_source_true_cinematic_wait_preserves_next_intro_policy() -> void:
	var fixture: Dictionary = _build_runtime_fixture(7)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var catalog: Object = fixture["catalog"]
	runtime.set("_choice_apply_flow", FakeAcceptedAngelApplyFlow.new(true))
	runtime.set("current_choice_context", {
		"source": "result_box_mythic_choice",
		"grant_scope": "stage_clear_result",
	})
	runtime.set("pending_skill_choices", 2)
	runtime.set("choice_active", true)
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "result-source cinematic=true fixture should accept Angel")
	var result_pending: Dictionary = _first_pending_roll(runtime)
	_expect(str(result_pending.get("policy", "")) == "next_valid_intro", "result-source reservation should use next-valid-intro policy")
	_expect(bool(result_pending.get("waiting_for_cinematic", false)), "result-source cinematic=true reservation should wait for its acquisition cinematic")
	_expect(not bool(result_pending.get("ready", true)), "result-source cinematic wait must not be ready before completion")

	var finish_result: Dictionary = _as_dictionary(runtime.call(
		"_finish_successful_choice",
		ANGEL_PERK_ID,
		owner,
		registry,
		null,
		_angel_choice()
	))
	_expect(not bool(finish_result.get("opened_next_choice", true)), "result-source cinematic wait should defer the remaining choice")
	_expect(not runtime.is_choice_active() and int(runtime.get("pending_skill_choices")) == 1, "result-source wait should bank one remaining choice")
	_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 0, "result-source acquisition must not roll the ended Stage 7")

	var completion: Dictionary = runtime.on_angel_blessing_acquisition_cinematic_finished(
		ANGEL_PERK_ID,
		owner,
		registry
	)
	var after_completion: Dictionary = _first_pending_roll(runtime)
	_expect(str(after_completion.get("policy", "")) == "next_valid_intro", "cinematic completion must preserve next-valid-intro policy")
	_expect(not bool(after_completion.get("waiting_for_cinematic", true)), "result-source completion should release only the cinematic wait")
	_expect(bool(after_completion.get("ready", false)), "completed result-source reservation should be ready for a future intro")
	_expect(bool(completion.get("opened_next_choice", false)) and runtime.is_choice_active(), "result-source completion should open the remaining choice before any Angel presentation")
	_expect(int(catalog.get("get_choices_calls")) == 1, "result-source completion should build its remaining choice once")
	_expect(not runtime.is_angel_blessing_modal_active(), "next-valid-intro reservation must not open Angel on the result stage")
	_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 0, "result-source completion must leave the ended stage unrolled")


func _verify_natural_cinematic_completion_notifies_once() -> void:
	var helper := MythicItemAcquisitionCinematicRuntime.new()
	var owner := FakeOwner.new(3)
	root.add_child(owner)
	var recorder := CompletionRecorder.new()
	var registry := FakeRegistry.new({"runtime_perk_state": recorder})
	var host := FakeAcquisitionHost.new(true, true)
	var runtime := FakeAcquisitionRuntime.new(host)

	helper.update(runtime, 0.25, registry, owner)
	_expect(recorder.calls == 1, "natural active -> inactive cinematic edge should notify Angel completion once")
	_expect(recorder.last_perk_id == ANGEL_PERK_ID, "natural completion should forward the acquired Angel perk id")
	_expect(recorder.last_owner == owner, "natural completion should forward the battle owner")
	_expect(recorder.last_registry == registry, "natural completion should forward the originating registry")
	helper.update(runtime, 0.25, registry, owner)
	_expect(recorder.calls == 1, "subsequent inactive updates must not duplicate Angel completion")

	var reset_recorder := CompletionRecorder.new()
	var reset_registry := FakeRegistry.new({"runtime_perk_state": reset_recorder})
	var reset_host := FakeAcquisitionHost.new(true, false)
	var reset_runtime := FakeAcquisitionRuntime.new(reset_host)
	helper.reset(reset_runtime, reset_registry)
	helper.update(reset_runtime, 0.25, reset_registry, owner)
	_expect(reset_recorder.calls == 0, "external cinematic reset/cancel must not masquerade as natural completion")

	var inactive_recorder := CompletionRecorder.new()
	var inactive_registry := FakeRegistry.new({"runtime_perk_state": inactive_recorder})
	var inactive_runtime := FakeAcquisitionRuntime.new(FakeAcquisitionHost.new(false, false))
	helper.update(inactive_runtime, 0.25, inactive_registry, owner)
	_expect(inactive_recorder.calls == 0, "already-inactive cinematic updates must not notify completion")

	# Break the intentional recorder <-> registry assertion cycle before exit.
	recorder.last_owner = null
	recorder.last_registry = null
	registry.instances.clear()


func _verify_frame_flow_rechecks_synchronously_opened_modals() -> void:
	_verify_frame_flow_edge("angel")
	_verify_frame_flow_edge("choice")


func _verify_frame_flow_edge(mode: String) -> void:
	var fixture: Dictionary = _build_runtime_fixture(3)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	if mode == "angel":
		var modal_flow: Object = runtime.get("_angel_blessing_modal_flow")
		modal_flow.call(
			"queue_pending_reveal",
			3,
			{
				"rolled": true,
				"active_stage": 3,
				"roll_face": 1,
				"active_buff_ids": ["move_speed"],
			},
			"frame_flow_edge"
		)

	var probe := FrameCallbackProbe.new(mode, runtime, owner, registry)
	var deps := {
		"current_stage": 3,
		"runtime_perk_state": runtime,
		"mythic_item_runtime": FakeMythicPauseRuntime.new(),
		"power_state": FakePowerState.new(),
		"skill_orb_tooltip_active": false,
	}
	BattleFrameFlowController.new().update(1.0 / 60.0, deps, probe.build_callbacks())

	_expect(probe.count("update_mythic_items") == 1, "%s edge should originate inside update_mythic_items" % mode)
	if mode == "angel":
		_expect(runtime.is_angel_blessing_modal_active(), "update_mythic_items should synchronously open the Angel modal fixture")
	else:
		_expect(runtime.is_choice_active(), "update_mythic_items should synchronously open the normal choice fixture")
	for callback_name: String in [
		"update_player_control",
		"update_runtime_perk_resume",
		"update_active_items",
		"update_boss_ai",
		"update_ball",
		"update_lingpet",
	]:
		_expect(probe.count(callback_name) == 0, "%s synchronous modal must keep gameplay callback %s at zero" % [mode, callback_name])
	_expect(probe.count("update_effects") == 1, "%s synchronous modal edge should retain the paused effects redraw tick" % mode)
	_expect(probe.count("queue_redraw") == 1, "%s synchronous modal edge should request one redraw" % mode)


func _verify_round_boundary_releases_canceled_cinematic_wait() -> void:
	var fixture: Dictionary = _build_runtime_fixture(3)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	runtime.set("_choice_apply_flow", FakeAcceptedAngelApplyFlow.new())
	runtime.set("current_choice_context", {"source": "battle_mythic_jackpot"})
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "round-boundary fixture should accept cinematic-waiting Angel")
	_expect(bool(_first_pending_roll(runtime).get("waiting_for_cinematic", false)), "round-boundary fixture should begin behind the cinematic wait")

	# A score/round reset cancels the shared mythic cinematic externally, so no
	# natural active -> inactive completion callback will arrive. The accepted
	# current-stage reservation must become ready instead of waiting forever.
	runtime.on_angel_blessing_round_boundary()
	var pending_after_boundary: Dictionary = _first_pending_roll(runtime)
	_expect(not bool(pending_after_boundary.get("waiting_for_cinematic", true)), "round boundary must release a canceled acquisition-cinematic wait")
	_expect(bool(pending_after_boundary.get("ready", false)), "round boundary must preserve the accepted reservation as ready work")

	runtime.update_angel_blessing_acquisition(
		0.0,
		owner,
		registry,
		{},
		{"forced_face": 1, "forced_candidate_order": ["move_speed"]}
	)
	_expect(_pending_roll_count(runtime) == 0, "next rally update should consume the released current-stage reservation")
	_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 3, "next rally should resolve the preserved Angel roll for the current stage")


func _build_runtime_fixture(stage: int) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	var owner := FakeOwner.new(stage)
	root.add_child(owner)
	var catalog := FakeCatalog.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"mythic_item_runtime": FakeMythicPauseRuntime.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
		"smasher_skill_state": SmasherSkillState.new(),
	})
	return {
		"runtime": runtime,
		"owner": owner,
		"registry": registry,
		"catalog": catalog,
	}


func _angel_choice() -> Dictionary:
	return {
		"id": ANGEL_PERK_ID,
		"perk_id": ANGEL_PERK_ID,
		"name": "천사의 가호",
		"max_level": 1,
		"rarity": "mythic",
		"tree": "mythic",
		"description": "스테이지마다 천사의 주사위를 굴립니다.",
	}


func _snapshot(runtime: Object) -> Dictionary:
	return _as_dictionary(runtime.get_angel_blessing_acquisition_snapshot())


func _pending_roll_count(runtime: Object) -> int:
	var pending_value: Variant = _snapshot(runtime).get("pending_rolls", [])
	return (pending_value as Array).size() if pending_value is Array else 0


func _first_pending_roll(runtime: Object) -> Dictionary:
	var pending_value: Variant = _snapshot(runtime).get("pending_rolls", [])
	if not pending_value is Array or (pending_value as Array).is_empty():
		return {}
	return _as_dictionary((pending_value as Array)[0])


func _as_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_s4_integration_edges_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


class FakeAcceptedAngelApplyFlow:
	extends RefCounted

	var cinematic_started := true

	func _init(did_start_cinematic: bool = true) -> void:
		cinematic_started = did_start_cinematic

	func apply_choice_from_runtime_state(
		runtime_state: Object,
		choice: Dictionary,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null
	) -> Dictionary:
		var choice_id: String = str(choice.get("id", choice.get("perk_id", "")))
		var levels_value: Variant = runtime_state.get("runtime_skill_levels")
		if levels_value is Dictionary:
			(levels_value as Dictionary)[choice_id] = 1
		return {
			"accepted": true,
			"choice_id": choice_id,
			"mythic_acquisition_cinematic_started": cinematic_started,
		}


class FakeOwner:
	extends Node

	var current_stage := 1
	var arena_mode_enabled := false
	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false
	var runtime_perk_gold := 0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0

	func _init(stage: int) -> void:
		current_stage = stage

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeCatalog:
	extends RefCounted

	var get_choices_calls := 0

	func get_perk_data(perk_id: String) -> Dictionary:
		return {
			"id": ANGEL_PERK_ID,
			"name": "천사의 가호",
			"max_level": 1,
			"rarity": "mythic",
			"tree": "mythic",
		} if perk_id == ANGEL_PERK_ID else {}

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		get_choices_calls += 1
		return [{"id": "sentinel_next_choice", "name": "sentinel"}]

	func has_open_perk_slot(_runtime_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_slot_status(_runtime_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return {"count": 0, "limit": 8, "is_full": false}


class CompletionRecorder:
	extends RefCounted

	var calls := 0
	var last_perk_id := ""
	var last_owner: Object = null
	var last_registry: Object = null

	func on_angel_blessing_acquisition_cinematic_finished(
		perk_id: String,
		owner: Object = null,
		registry: Object = null
	) -> Dictionary:
		calls += 1
		last_perk_id = perk_id
		last_owner = owner
		last_registry = registry
		return {"accepted": true}


class FakeAcquisitionRuntime:
	extends RefCounted

	var acquisition_cinematic: Object

	func _init(host: Object) -> void:
		acquisition_cinematic = host


class FakeAcquisitionHost:
	extends RefCounted

	var active := false
	var finish_on_update := false
	var update_calls := 0
	var reset_calls := 0

	func _init(initially_active: bool, should_finish_on_update: bool) -> void:
		active = initially_active
		finish_on_update = should_finish_on_update

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {
			"active": active,
			"item_data": {
				"id": ANGEL_PERK_ID,
				"perk_id": ANGEL_PERK_ID,
			},
		}

	func update(_delta: float, _registry: Object = null) -> void:
		update_calls += 1
		if finish_on_update:
			active = false

	func reset(_registry: Object = null) -> void:
		reset_calls += 1
		active = false


class FakeStartResultMythicRuntime:
	extends RefCounted

	var start_result := false
	var start_calls := 0

	func _init(result: bool) -> void:
		start_result = result

	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		start_calls += 1
		return start_result


class FakeMythicPauseRuntime:
	extends RefCounted

	func should_pause_game() -> bool:
		return false

	func is_baal_boots_cinematic_active() -> bool:
		return false

	func is_acquisition_cinematic_active() -> bool:
		return false

	func refresh_runtime_perk_scaling(_owner: Object = null, _registry: Object = null) -> void:
		pass


class FakePowerState:
	extends RefCounted

	func is_freeze_active() -> bool:
		return false


class FrameCallbackProbe:
	extends RefCounted

	var mode: String
	var runtime: Object
	var owner: Object
	var registry: Object
	var calls: Dictionary = {}

	func _init(edge_mode: String, perk_runtime: Object, battle_owner: Object, battle_registry: Object) -> void:
		mode = edge_mode
		runtime = perk_runtime
		owner = battle_owner
		registry = battle_registry

	func build_callbacks() -> Dictionary:
		return {
			"update_weather": Callable(self, "update_weather"),
			"update_mythic_items": Callable(self, "update_mythic_items"),
			"update_player_control": Callable(self, "update_player_control"),
			"update_runtime_perk_resume": Callable(self, "update_runtime_perk_resume"),
			"update_active_items": Callable(self, "update_active_items"),
			"update_boss_ai": Callable(self, "update_boss_ai"),
			"update_ball": Callable(self, "update_ball"),
			"update_lingpet": Callable(self, "update_lingpet"),
			"update_effects": Callable(self, "update_effects"),
			"queue_redraw": Callable(self, "queue_redraw"),
		}

	func count(key: String) -> int:
		return int(calls.get(key, 0))

	func update_weather(_delta: float) -> void:
		_record("update_weather")

	func update_mythic_items(_delta: float) -> void:
		_record("update_mythic_items")
		if mode == "angel":
			runtime.update_angel_blessing_acquisition(0.0, owner, registry)
		else:
			runtime.set("choice_active", true)

	func update_player_control(_delta: float) -> void:
		_record("update_player_control")

	func update_runtime_perk_resume(_delta: float) -> void:
		_record("update_runtime_perk_resume")

	func update_active_items(_delta: float) -> void:
		_record("update_active_items")

	func update_boss_ai(_delta: float) -> void:
		_record("update_boss_ai")

	func update_ball(_delta: float) -> void:
		_record("update_ball")

	func update_lingpet(_delta: float) -> void:
		_record("update_lingpet")

	func update_effects(_delta: float) -> void:
		_record("update_effects")

	func queue_redraw() -> void:
		_record("queue_redraw")

	func _record(key: String) -> void:
		calls[key] = int(calls.get(key, 0)) + 1
