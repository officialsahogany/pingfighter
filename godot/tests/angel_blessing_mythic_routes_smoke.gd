extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")
const StageClearResultImmediateRewardGrantData := preload("res://scripts/core/stage_clear_result_immediate_reward_grant_data.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")

const ANGEL_PERK_ID := "angel_blessing"
const REQUIRED_FACADES := [
	"get_angel_blessing_acquisition_snapshot",
	"has_pending_angel_blessing_acquisition",
	"update_angel_blessing_acquisition",
	"on_angel_blessing_acquisition_cinematic_finished",
	"on_angel_blessing_round_boundary",
	"on_angel_blessing_stage_transition",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe: Object = RuntimePerkState.new()
	if not _require_facades(probe, REQUIRED_FACADES):
		_finish()
		return

	_verify_battle_grant_waits_for_cinematic_and_only_rolls_angel()
	_verify_result_direct_and_choice_sources_wait_for_future_intro()
	_verify_duplicate_failed_and_full_slot_do_not_reserve()
	_verify_cinematic_choice_angel_modal_order()
	_verify_queue_dedupe_and_boundary_resets()
	_finish()


func _verify_battle_grant_waits_for_cinematic_and_only_rolls_angel() -> void:
	var fixture: Dictionary = _build_fixture(3)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var cinematic: Object = fixture["cinematic"]

	# This unrelated deferred instant must stay queued when the mid-stage Angel
	# acquisition resolves. Calling the whole spawn-intro facade here is a bug.
	runtime.call("_queue_full_gauge_after_spawn_intro", owner, "full gauge sentinel")
	_expect(runtime.has_pending_full_gauge_after_spawn_intro(), "fixture should begin with a deferred full-gauge sentinel")
	cinematic.set("active", true)
	runtime.set("current_choice_context", {"source": "battle_mythic_jackpot", "grant_scope": "battle"})
	var accepted: bool = bool(runtime.apply_choice(_angel_choice(), owner, registry))
	_expect(accepted, "first battle Angel choice should be accepted")
	_expect(runtime.get_runtime_skill_level(ANGEL_PERK_ID) == 1, "accepted battle grant should commit raw Angel level 0 -> 1")
	_expect(_pending_roll_count(runtime) == 1, "accepted 0 -> 1 battle grant should reserve exactly one current-stage roll")
	var pending: Dictionary = _first_pending_roll(runtime)
	_expect(int(pending.get("stage", 0)) == 3, "battle reservation should bind to the actual current stage")
	_expect(str(pending.get("policy", "")) == "current_stage", "battle reservation should use current-stage policy")

	_call_angel_update(
		runtime,
		0.25,
		owner,
		registry,
		{"mythic_acquisition_cinematic_active": true},
		_forced_roll_options()
	)
	_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 0, "Angel must not roll while its acquisition cinematic is active")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal must not overlap the acquisition cinematic")

	cinematic.set("active", false)
	runtime.call("on_angel_blessing_acquisition_cinematic_finished", ANGEL_PERK_ID)
	_call_angel_update(runtime, 0.0, owner, registry, {}, _forced_roll_options())
	var rolled_snapshot: Dictionary = runtime.get_angel_blessing_snapshot()
	_expect(int(rolled_snapshot.get("active_stage", 0)) == 3, "cinematic completion should roll the reserved current stage")
	_expect(rolled_snapshot.get("active_buff_ids", []) == ["move_speed"], "forced battle reservation should roll only the requested Angel lane")
	_expect(runtime.has_pending_full_gauge_after_spawn_intro(), "mid-stage Angel completion must not flush an unrelated deferred full gauge")
	_expect(_pending_roll_count(runtime) == 0, "successful current-stage reservation should drain once")

	var revision_before_repeat: int = int(rolled_snapshot.get("revision", -1))
	_call_angel_update(runtime, 0.25, owner, registry, {}, _forced_roll_options())
	_expect(int(runtime.get_angel_blessing_snapshot().get("revision", -2)) == revision_before_repeat, "repeated idle updates must not reroll the same acquisition")


func _verify_result_direct_and_choice_sources_wait_for_future_intro() -> void:
	for defer_starpoint_choice: bool in [false, true]:
		var fixture: Dictionary = _build_fixture(7)
		var runtime: Object = fixture["runtime"]
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		var reward: Dictionary = _angel_choice()
		reward["type"] = StageClearRewardResolver.REWARD_MYTHIC_PERK
		reward["perk_id"] = ANGEL_PERK_ID
		reward["perk_data"] = _angel_choice()
		var grant_result: Dictionary = StageClearResultImmediateRewardGrantData.grant_immediate_box_reward(
			reward,
			owner,
			registry,
			defer_starpoint_choice,
			StageClearRewardResolver.new()
		)
		_expect(bool(grant_result.get("granted", false)), "result direct Angel reward should grant regardless of starpoint deferral flag")
		_expect(runtime.get_runtime_skill_level(ANGEL_PERK_ID) == 1, "result direct grant should commit Angel ownership")
		_expect(int(runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 0, "result direct grant must not roll the completed Stage 7")
		var pending: Dictionary = _first_pending_roll(runtime)
		_expect(str(pending.get("policy", "")) == "next_valid_intro", "result direct grant should carry explicit next-valid-intro context")
		_expect(int(pending.get("stage", -1)) == 0, "result reservation must not guess current_stage + 1")

		# The dedicated Angel icon now lets the result reward start its real mythic
		# acquisition cinematic. Production reaches the next intro only after that
		# cinematic has gone inactive and emitted its completion callback.
		var cinematic: Object = fixture["cinematic"]
		cinematic.set("active", false)
		runtime.on_angel_blessing_acquisition_cinematic_finished(
			ANGEL_PERK_ID,
			owner,
			registry
		)
		owner.set("current_stage", 9)
		runtime.on_ball_spawn_intro_finished(owner, registry, _forced_roll_options())
		var future_snapshot: Dictionary = runtime.get_angel_blessing_snapshot()
		_expect(int(future_snapshot.get("active_stage", 0)) == 9, "next-valid-intro reservation should use the actual future Stage 9")
		_expect(_pending_roll_count(runtime) == 0, "future intro should consume the result reservation exactly once")

	var choice_fixture: Dictionary = _build_fixture(6)
	var choice_runtime: Object = choice_fixture["runtime"]
	var choice_owner: Object = choice_fixture["owner"]
	var choice_registry: Object = choice_fixture["registry"]
	choice_runtime.set("current_choice_context", {
		"source": "result_box_mythic_choice",
		"grant_scope": "stage_clear_result",
	})
	_expect(bool(choice_runtime.apply_choice(_angel_choice(), choice_owner, choice_registry)), "result mythic choice source should accept Angel")
	var choice_pending: Dictionary = _first_pending_roll(choice_runtime)
	_expect(str(choice_pending.get("policy", "")) == "next_valid_intro", "result mythic choice source should share direct-grant deferral semantics")
	_expect(int(choice_runtime.get_angel_blessing_snapshot().get("active_stage", 0)) == 0, "result mythic choice must leave the completed stage untouched")


func _verify_duplicate_failed_and_full_slot_do_not_reserve() -> void:
	var duplicate_fixture: Dictionary = _build_fixture(4)
	var duplicate_runtime: Object = duplicate_fixture["runtime"]
	duplicate_runtime.runtime_skill_levels[ANGEL_PERK_ID] = 1
	var duplicate_accepted: bool = bool(duplicate_runtime.apply_choice(
		_angel_choice(),
		duplicate_fixture["owner"],
		duplicate_fixture["registry"]
	))
	_expect(duplicate_accepted, "max-level 1 -> 1 path may remain accepted by generic level bookkeeping")
	_expect(_pending_roll_count(duplicate_runtime) == 0, "accepted duplicate 1 -> 1 must not reserve Angel acquisition")

	var failed_fixture: Dictionary = _build_fixture(4)
	var failed_runtime: Object = failed_fixture["runtime"]
	_expect(not bool(failed_runtime.apply_choice({}, failed_fixture["owner"], failed_fixture["registry"])), "empty choice should be rejected")
	_expect(_pending_roll_count(failed_runtime) == 0, "failed apply must not reserve Angel acquisition")
	_expect(not bool(failed_runtime.call("has_pending_angel_blessing_acquisition")), "failed apply should leave the public pending query false")

	var full_fixture: Dictionary = _build_fixture(5, false)
	var full_runtime: Object = full_fixture["runtime"]
	var full_reward: Dictionary = _angel_choice()
	full_reward["type"] = StageClearRewardResolver.REWARD_MYTHIC_PERK
	full_reward["perk_id"] = ANGEL_PERK_ID
	full_reward["fallback_starpoints"] = 3
	var full_result: Dictionary = StageClearResultImmediateRewardGrantData.grant_immediate_box_reward(
		full_reward,
		full_fixture["owner"],
		full_fixture["registry"],
		true,
		StageClearRewardResolver.new()
	)
	_expect(bool(full_result.get("granted", false)), "full-slot result route should grant its starpoint fallback")
	_expect(full_runtime.get_runtime_skill_level(ANGEL_PERK_ID) == 0, "full-slot fallback must not create Angel ownership")
	_expect(_pending_roll_count(full_runtime) == 0, "full-slot fallback must not reserve Angel activation")


func _verify_cinematic_choice_angel_modal_order() -> void:
	var fixture: Dictionary = _build_fixture(4)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var cinematic: Object = fixture["cinematic"]
	cinematic.set("active", true)
	runtime.set("current_choice_context", {"source": "battle_mythic_jackpot"})
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "ordering fixture should accept Angel")

	# This represents the next already-earned runtime choice. It must stay ahead
	# of Angel after the acquisition cinematic closes.
	runtime.set("pending_skill_choices", 1)
	runtime.set("choice_active", true)
	cinematic.set("active", false)
	runtime.call("on_angel_blessing_acquisition_cinematic_finished", ANGEL_PERK_ID)
	_call_angel_update(
		runtime,
		0.0,
		owner,
		registry,
		{"runtime_perk_choice_active": true},
		_forced_roll_options()
	)
	_expect(bool(runtime.get("choice_active")), "remaining runtime choice should stay active ahead of Angel")
	_expect(int(runtime.get("pending_skill_choices")) == 1, "Angel wait must not consume the remaining choice transaction")
	_expect(not bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal must not overlap the remaining runtime choice")

	runtime.set("choice_active", false)
	runtime.set("pending_skill_choices", 0)
	_call_angel_update(runtime, 0.0, owner, registry, {}, _forced_roll_options())
	_expect(bool(runtime.call("is_angel_blessing_modal_active")), "Angel modal should open only after acquisition and remaining choice are both closed")


func _verify_queue_dedupe_and_boundary_resets() -> void:
	var fixture: Dictionary = _build_fixture(5)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	fixture["cinematic"].set("active", true)
	runtime.set("current_choice_context", {"source": "battle_debug_grant"})
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "dedupe fixture first apply should succeed")
	_expect(bool(runtime.apply_choice(_angel_choice(), owner, registry)), "dedupe fixture duplicate generic apply may remain accepted")
	_expect(_pending_roll_count(runtime) == 1, "same stage and acquisition reason should dedupe to one pending roll")

	runtime.call("on_angel_blessing_round_boundary")
	_expect(_pending_roll_count(runtime) == 1, "round boundary must preserve an accepted grant whose cinematic was canceled by reset")
	runtime.call("on_angel_blessing_stage_transition", 6)
	_expect(_pending_roll_count(runtime) == 0, "stage transition should discard stale current-stage acquisition work")

	var result_fixture: Dictionary = _build_fixture(5)
	var result_runtime: Object = result_fixture["runtime"]
	result_runtime.set("current_choice_context", {
		"source": "result_box_mythic_choice",
		"grant_scope": "stage_clear_result",
	})
	_expect(bool(result_runtime.apply_choice(_angel_choice(), result_fixture["owner"], result_fixture["registry"])), "result reset fixture should accept Angel")
	result_runtime.call("on_angel_blessing_stage_transition", 6)
	_expect(_pending_roll_count(result_runtime) == 1, "stage transition should preserve next-valid-intro result work")
	result_runtime.reset()
	_expect(_pending_roll_count(result_runtime) == 0, "full reset should clear every pending Angel roll")
	_expect(not bool(result_runtime.call("has_pending_angel_blessing_acquisition")), "full reset should clear the public Angel work query")
	_expect(result_runtime.get_runtime_skill_level(ANGEL_PERK_ID) == 0, "full reset should clear Angel ownership")


func _build_fixture(stage: int, slot_open: bool = true) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	var owner := FakeOwner.new(stage)
	root.add_child(owner)
	var cinematic := FakeMythicRuntime.new()
	var catalog := FakeCatalog.new(slot_open)
	var skill_config: Object = SmasherSkillConfig.new()
	var skill_state: Object = SmasherSkillState.new()
	var registry := FakeRegistry.new({
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
		"mythic_item_runtime": cinematic,
		"smasher_skill_config": skill_config,
		"smasher_skill_state": skill_state,
	})
	return {
		"runtime": runtime,
		"owner": owner,
		"registry": registry,
		"cinematic": cinematic,
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
		"descriptions": {1: "스테이지마다 천사의 주사위를 굴립니다."},
	}


func _forced_roll_options() -> Dictionary:
	return {
		"forced_face": 1,
		"forced_candidate_order": ["move_speed"],
	}


func _call_angel_update(
	runtime: Object,
	delta: float,
	owner: Object,
	registry: Object,
	blockers: Dictionary,
	roll_options: Dictionary
) -> Dictionary:
	var value: Variant = runtime.callv(
		"update_angel_blessing_acquisition",
		[delta, owner, registry, blockers, roll_options]
	)
	return _as_dictionary(value)


func _acquisition_snapshot(runtime: Object) -> Dictionary:
	return _as_dictionary(runtime.call("get_angel_blessing_acquisition_snapshot"))


func _pending_roll_count(runtime: Object) -> int:
	var pending_value: Variant = _acquisition_snapshot(runtime).get("pending_rolls", [])
	return (pending_value as Array).size() if pending_value is Array else 0


func _first_pending_roll(runtime: Object) -> Dictionary:
	var pending_value: Variant = _acquisition_snapshot(runtime).get("pending_rolls", [])
	if not pending_value is Array or (pending_value as Array).is_empty():
		return {}
	return _as_dictionary((pending_value as Array)[0])


func _require_facades(runtime: Object, names: Array) -> bool:
	var complete := true
	for name_value: Variant in names:
		var method_name: String = str(name_value)
		if runtime.has_method(method_name):
			continue
		complete = false
		_failures.append("missing RuntimePerkState S4 facade: %s" % method_name)
	return complete


func _as_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_mythic_routes_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


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


class FakeMythicRuntime:
	extends RefCounted

	var active := false
	var start_calls := 0

	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		start_calls += 1
		active = true
		return true

	func is_acquisition_cinematic_active() -> bool:
		return active

	func refresh_runtime_perk_scaling(_owner: Object = null, _registry: Object = null) -> void:
		pass


class FakeCatalog:
	extends RefCounted

	var slot_open := true

	func _init(is_open: bool) -> void:
		slot_open = is_open

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id != ANGEL_PERK_ID:
			return {}
		return {
			"id": ANGEL_PERK_ID,
			"perk_id": ANGEL_PERK_ID,
			"name": "천사의 가호",
			"max_level": 1,
			"rarity": "mythic",
			"tree": "mythic",
			"description": "스테이지마다 천사의 주사위를 굴립니다.",
			"descriptions": {1: "스테이지마다 천사의 주사위를 굴립니다."},
		}

	func has_open_perk_slot(_runtime_levels: Dictionary, _registry: Object = null) -> bool:
		return slot_open

	func get_perk_slot_status(_runtime_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return {
			"count": 0 if slot_open else 8,
			"limit": 8,
			"is_full": not slot_open,
		}

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return []
