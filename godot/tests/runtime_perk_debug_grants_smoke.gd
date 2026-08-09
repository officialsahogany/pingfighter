extends SceneTree

const RuntimePerkDebugGrants := preload("res://scripts/characters/runtime_perk_debug_grants.gd")

var _failures: Array[String] = []
var _apply_choice_calls := 0
var _apply_unlock_choice_calls := 0
var _apply_level_side_effect_calls := 0
var _apply_feedback_calls := 0
var _sync_owner_calls := 0
var _last_choice_data: Dictionary = {}


func _init() -> void:
	_verify_path_selection()
	_verify_choice_data_patches()
	_verify_choice_data_update_application()
	_verify_post_apply_update()
	_verify_state_applications()
	_verify_debug_grant_orchestration()
	_verify_runtime_state_facade_owns_deps_and_defaults()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_debug_grants_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_path_selection() -> void:
	var helper := RuntimePerkDebugGrants.new()
	_expect_path(helper.build_path("", {"name": "Blank"}), RuntimePerkDebugGrants.PATH_INVALID, false, "blank id should reject")
	_expect_path(helper.build_path("missing", {}), RuntimePerkDebugGrants.PATH_INVALID, false, "empty perk data should reject")
	_expect_path(helper.build_path("instant_debug", {"is_instant": true}), RuntimePerkDebugGrants.PATH_INSTANT, true, "instant flag should select instant path")
	_expect_path(helper.build_path("convert_to_gold", {"name": "Gold"}), RuntimePerkDebugGrants.PATH_INSTANT, true, "gold conversion should select instant path")
	_expect_path(helper.build_path("unlock_plasma", {"unlocks_skill": "plasma"}), RuntimePerkDebugGrants.PATH_UNLOCK, true, "unlock data should select unlock path")
	_expect_path(helper.build_path("common_bulk_up", {"max_level": 5}), RuntimePerkDebugGrants.PATH_LEVEL, true, "ordinary data should select level path")


func _verify_choice_data_patches() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var instant_patch: Dictionary = helper.build_choice_data_patch(
		RuntimePerkDebugGrants.PATH_INSTANT,
		{"accepted": true, "current_level": 0, "next_level": 0}
	)
	_expect(int(_patch(instant_patch).get("current_level", -1)) == 0, "instant patch should expose current level")
	_expect(int(_patch(instant_patch).get("next_level", -1)) == 0, "instant patch should expose next level")

	var unlock_patch: Dictionary = helper.build_choice_data_patch(
		RuntimePerkDebugGrants.PATH_UNLOCK,
		{"accepted": true, "current_level": 0, "next_level": 2},
		1
	)
	_expect(int(_patch(unlock_patch).get("next_level", 0)) == 2, "unlock patch should expose next level")

	var level_patch: Dictionary = helper.build_choice_data_patch(
		RuntimePerkDebugGrants.PATH_LEVEL,
		{"accepted": true, "next_level": 4},
		1
	)
	_expect(int(_patch(level_patch).get("current_level", -1)) == 3, "level patch should derive current display level from next level")
	_expect(int(_patch(level_patch).get("next_level", 0)) == 4, "level patch should expose next level")
	var rejected: Dictionary = helper.build_choice_data_patch(RuntimePerkDebugGrants.PATH_LEVEL, {"accepted": false}, 1)
	_expect(not bool(rejected.get("accepted", true)), "choice data patch should reject rejected helper updates")


func _verify_choice_data_update_application() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var data := {"id": "common_bulk_up"}
	var applied: Dictionary = helper.apply_choice_data_update(
		data,
		RuntimePerkDebugGrants.PATH_LEVEL,
		{"accepted": true, "next_level": 3},
		1
	)
	_expect(bool(applied.get("accepted", false)), "combined choice data update should accept valid helper updates")
	_expect(int(data.get("current_level", -1)) == 2, "combined choice data update should apply current display level")
	_expect(int(data.get("next_level", -1)) == 3, "combined choice data update should apply next display level")
	var rejected: Dictionary = helper.apply_choice_data_update(
		data,
		RuntimePerkDebugGrants.PATH_LEVEL,
		{"accepted": false},
		1
	)
	_expect(not bool(rejected.get("accepted", true)), "combined choice data update should reject rejected helper updates")


func _verify_post_apply_update() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var update: Dictionary = helper.build_post_apply_update(" common_bulk_up ")
	_expect(bool(update.get("accepted", false)), "post-apply update should accept valid ids")
	_expect(str(update.get("last_selected_id", "")) == "common_bulk_up", "post-apply update should normalize the last-selected id")
	_expect(bool(update.get("sync_owner", false)), "post-apply update should request owner sync")
	_expect(not bool(helper.build_post_apply_update("").get("accepted", true)), "post-apply update should reject blank ids")


func _verify_state_applications() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var data := {"id": "common_bulk_up"}
	var patch_result: Dictionary = helper.build_choice_data_patch(
		RuntimePerkDebugGrants.PATH_LEVEL,
		{"accepted": true, "next_level": 4},
		1
	)
	_expect(helper.apply_choice_data_patch(data, patch_result), "choice data patch application should accept valid patches")
	_expect(int(data.get("current_level", -1)) == 3, "choice data patch application should write current level")
	_expect(int(data.get("next_level", -1)) == 4, "choice data patch application should write next level")
	_expect(not helper.apply_choice_data_patch(data, {"accepted": false}), "choice data patch application should reject rejected patches")

	var runtime_levels: Dictionary = {}
	var runtime_patch_update: Dictionary = helper.build_runtime_level_patch_update(" common_bulk_up ", patch_result, 1)
	_expect(bool(runtime_patch_update.get("accepted", false)), "runtime level patch update should accept valid patch results")
	_expect(str(runtime_patch_update.get("perk_id", "")) == "common_bulk_up", "runtime level patch update should normalize perk ids")
	_expect(int(runtime_patch_update.get("level", 0)) == 4, "runtime level patch update should expose the patched next level")
	var runtime_patch_result: Dictionary = helper.apply_runtime_level_patch(runtime_levels, runtime_patch_update)
	_expect(bool(runtime_patch_result.get("accepted", false)), "runtime level patch application should accept valid updates")
	_expect(int(runtime_levels.get("common_bulk_up", 0)) == 4, "runtime level patch application should write runtime levels")
	_expect(not bool(helper.build_runtime_level_patch_update("", patch_result, 1).get("accepted", true)), "runtime level patch update should reject blank ids")
	_expect(not bool(helper.build_runtime_level_patch_update("common_bulk_up", {"accepted": false}, 1).get("accepted", true)), "runtime level patch update should reject rejected patch results")
	_expect(not bool(helper.apply_runtime_level_patch(runtime_levels, {"accepted": false}).get("accepted", true)), "runtime level patch application should reject rejected updates")
	_expect(not bool(helper.apply_runtime_level_patch(runtime_levels, {"accepted": true, "perk_id": ""}).get("accepted", true)), "runtime level patch application should reject blank update ids")

	var state := FakeRuntimeState.new()
	var owner := FakeOwner.new()
	var post_result: Dictionary = helper.build_post_apply_update(" common_bulk_up ")
	_expect(
		helper.apply_post_apply_update(state, owner, post_result, Callable(owner, "sync_owner")),
		"post-apply application should accept valid updates"
	)
	_expect(state.last_selected_id == "common_bulk_up", "post-apply application should set last selected id")
	_expect(owner.sync_count == 1, "post-apply application should request owner sync")
	_expect(
		helper.apply_post_apply_for_perk(state, owner, " unlock_plasma ", Callable(owner, "sync_owner")),
		"post-apply shorthand should build and apply perk updates"
	)
	_expect(state.last_selected_id == "unlock_plasma", "post-apply shorthand should normalize perk ids")
	_expect(owner.sync_count == 2, "post-apply shorthand should request owner sync")
	_expect(
		not helper.apply_post_apply_update(null, owner, post_result, Callable(owner, "sync_owner")),
		"post-apply application should reject missing state"
	)


func _verify_debug_grant_orchestration() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var state := FakeRuntimeState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	_reset_grant_calls()
	var level_catalog := FakeCatalog.new({
		"common_bulk_up": {"name": "Bulk", "max_level": 5},
	})
	var levels: Dictionary = {}
	var level_result: Dictionary = helper.apply_debug_grant(
		state,
		" common_bulk_up ",
		3,
		owner,
		registry,
		level_catalog,
		levels,
		1.1,
		_grant_callbacks()
	)
	_expect(bool(level_result.get("accepted", false)), "debug grant orchestration should accept ordinary level grants")
	_expect(str(level_result.get("path", "")) == RuntimePerkDebugGrants.PATH_LEVEL, "debug grant orchestration should report the level path")
	_expect(int(levels.get("common_bulk_up", 0)) == 3, "debug grant orchestration should patch runtime levels")
	_expect(_apply_level_side_effect_calls == 1, "debug grant orchestration should call level side effects once")
	_expect(_apply_feedback_calls == 1, "debug grant orchestration should apply level feedback once")
	_expect(state.last_selected_id == "common_bulk_up", "debug grant orchestration should update last-selected id")
	_expect(_sync_owner_calls == 1, "debug grant orchestration should sync owner after level grant")

	_reset_grant_calls()
	var instant_catalog := FakeCatalog.new({
		"instant_debug": {"name": "Instant", "is_instant": true},
	})
	var instant_result: Dictionary = helper.apply_debug_grant(
		state,
		"instant_debug",
		1,
		owner,
		registry,
		instant_catalog,
		levels,
		1.1,
		_grant_callbacks()
	)
	_expect(bool(instant_result.get("accepted", false)), "debug grant orchestration should accept instant grants")
	_expect(str(instant_result.get("path", "")) == RuntimePerkDebugGrants.PATH_INSTANT, "debug grant orchestration should report the instant path")
	_expect(_apply_choice_calls == 1, "debug grant orchestration should route instant grants through apply_choice")
	_expect(int(_last_choice_data.get("next_level", -1)) == 0, "debug grant orchestration should patch instant display level")
	_expect(_sync_owner_calls == 1, "debug grant orchestration should sync owner after instant grant")

	_reset_grant_calls()
	var unlock_catalog := FakeCatalog.new({
		"unlock_plasma": {"name": "Plasma", "max_level": 2, "unlocks_skill": "plasma"},
	})
	var unlock_result: Dictionary = helper.apply_debug_grant(
		state,
		"unlock_plasma",
		2,
		owner,
		registry,
		unlock_catalog,
		levels,
		1.1,
		_grant_callbacks()
	)
	_expect(bool(unlock_result.get("accepted", false)), "debug grant orchestration should accept unlock grants")
	_expect(str(unlock_result.get("path", "")) == RuntimePerkDebugGrants.PATH_UNLOCK, "debug grant orchestration should report the unlock path")
	_expect(_apply_unlock_choice_calls == 1, "debug grant orchestration should route unlock grants through unlock choice apply")
	_expect(int(_last_choice_data.get("next_level", -1)) == 2, "debug grant orchestration should patch unlock display level")

	_reset_grant_calls()
	var guardian_catalog := FakeCatalog.new({
		"lingpet_guardian_enhance": {
			"name": "수호령강화",
			"max_level": 1,
			"is_lingpet_guardian_enhance": true,
			"tree": "lingpet",
		},
	})
	var guardian_registry := FakeLingpetRegistry.new()
	var guardian_result: Dictionary = helper.apply_debug_grant(
		state,
		"lingpet_guardian_enhance",
		1,
		owner,
		guardian_registry,
		guardian_catalog,
		levels,
		1.1,
		_grant_callbacks()
	)
	_expect(bool(guardian_result.get("accepted", false)), "guardian-enhance debug grant should be accepted")
	_expect(
		str(guardian_result.get("path", "")) == RuntimePerkDebugGrants.PATH_GUARDIAN_ENHANCE,
		"guardian-enhance debug grant should report the guardian path"
	)
	_expect(_apply_choice_calls == 1, "guardian-enhance debug grant should route through apply_choice")
	_expect(
		guardian_registry.lingpet_runtime.candidate_build_calls == 1,
		"guardian-enhance debug grant should build live candidates from the lingpet runtime"
	)
	var injected_candidates: Array = _last_choice_data.get("guardian_enhance_candidates", []) as Array
	_expect(injected_candidates.size() == 1, "guardian-enhance debug grant should inject live candidates into the choice data")
	_expect(not levels.has("lingpet_guardian_enhance"), "guardian-enhance debug grant should not write runtime skill levels")
	_expect(_apply_level_side_effect_calls == 0, "guardian-enhance debug grant should not run level side effects")

	_reset_grant_calls()
	var guardian_missing_runtime_result: Dictionary = helper.apply_debug_grant(
		state,
		"lingpet_guardian_enhance",
		1,
		owner,
		registry,
		guardian_catalog,
		levels,
		1.1,
		_grant_callbacks()
	)
	_expect(
		not bool(guardian_missing_runtime_result.get("accepted", true)),
		"guardian-enhance debug grant should reject without a lingpet runtime"
	)
	_expect(
		str(guardian_missing_runtime_result.get("blocked_reason", "")) == "missing_lingpet_runtime",
		"guardian-enhance rejection should name the missing runtime"
	)
	_expect(_apply_choice_calls == 0, "guardian-enhance rejection should not reach apply_choice")

	_reset_grant_calls()
func _verify_runtime_state_facade_owns_deps_and_defaults() -> void:
	var helper := RuntimePerkDebugGrants.new()
	var state := FakeRuntimeState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var catalog := FakeCatalog.new({
		"common_bulk_up": {"name": "Bulk", "max_level": 5},
		"instant_debug": {"name": "Instant", "is_instant": true},
		"unlock_plasma": {"name": "Plasma", "max_level": 2, "unlocks_skill": "plasma"},
	})

	var level_result: Dictionary = helper.apply_debug_grant_from_runtime_state(
		state,
		" common_bulk_up ",
		4,
		owner,
		registry,
		catalog
	)
	_expect(bool(level_result.get("accepted", false)), "debug facade should accept ordinary level grants")
	_expect(int(state.runtime_skill_levels.get("common_bulk_up", 0)) == 4, "debug facade should patch live runtime levels")
	_expect(state.apply_level_side_effect_calls == 1, "debug facade should build level side-effect callback internally")
	_expect(state.apply_feedback_calls == 1, "debug facade should build feedback callback internally")
	_expect(
		is_equal_approx(state.last_feedback_timer, float(state._level_side_effects.get("LEVEL_FEEDBACK_TIMER"))),
		"debug facade should use level-side-effect feedback timer"
	)
	_expect(state.sync_owner_calls == 1, "debug facade should build owner sync callback internally")
	_expect(state.last_selected_id == "common_bulk_up", "debug facade should apply post-grant last-selected id")

	state.reset_calls()
	var instant_result: Dictionary = helper.apply_debug_grant_from_runtime_state(
		state,
		"instant_debug",
		1,
		owner,
		registry,
		catalog
	)
	_expect(bool(instant_result.get("accepted", false)), "debug facade should accept instant grants")
	_expect(state.apply_choice_calls == 1, "debug facade should route instant grants through state apply_choice")
	_expect(int(state.last_choice_data.get("next_level", -1)) == 0, "debug facade should patch instant display levels")

	state.reset_calls()
	var unlock_result: Dictionary = helper.apply_debug_grant_from_runtime_state(
		state,
		"unlock_plasma",
		2,
		owner,
		registry,
		catalog
	)
	_expect(bool(unlock_result.get("accepted", false)), "debug facade should accept unlock grants")
	_expect(state.apply_unlock_choice_calls == 1, "debug facade should route unlock grants through state unlock callback")
	_expect(int(state.last_choice_data.get("next_level", -1)) == 2, "debug facade should patch unlock display levels")

	state.reset_calls()
	var guardian_facade_registry := FakeLingpetRegistry.new()
	var guardian_facade_result: Dictionary = helper.apply_debug_grant_from_runtime_state(
		state,
		"lingpet_guardian_enhance",
		1,
		owner,
		guardian_facade_registry,
		FakeCatalog.new({
			"lingpet_guardian_enhance": {
				"name": "수호령강화",
				"max_level": 1,
				"is_lingpet_guardian_enhance": true,
			},
		})
	)
	_expect(bool(guardian_facade_result.get("accepted", false)), "debug facade should accept guardian-enhance grants")
	_expect(state.apply_choice_calls == 1, "debug facade should route guardian-enhance grants through state apply_choice")
	_expect(
		(state.last_choice_data.get("guardian_enhance_candidates", []) as Array).size() == 1,
		"debug facade should inject live candidates for guardian-enhance grants"
	)
	_expect(
		not state.runtime_skill_levels.has("lingpet_guardian_enhance"),
		"debug facade should not write runtime levels for guardian-enhance grants"
	)

	state.reset_calls()
func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	_expect(state_source.find("RuntimePerkDebugGrants") >= 0, "state should preload debug grants helper")
	_expect(state_source.find("_debug_grants.apply_debug_grant_from_runtime_state") >= 0, "state should route debug grants through the helper facade")
	_expect(state_source.find("_debug_grants.build_grant_callbacks") < 0, "state should not build debug callback maps inline")
	_expect(helper_source.find("func apply_debug_grant_from_runtime_state(") >= 0, "helper should expose a runtime-state debug grant facade")
	_expect(helper_source.find("func apply_debug_grant(") >= 0, "helper should own debug grant orchestration")
	_expect(helper_source.find("func build_grant_callbacks(") >= 0, "helper should own debug grant callback assembly")
	var facade_body: String = _function_body(helper_source, "func apply_debug_grant_from_runtime_state(")
	var debug_body: String = _function_body(state_source, "func debug_set_perk_level(")
	_expect(debug_body.find("runtime_skill_levels") < 0, "debug setter should not pass runtime levels inline")
	_expect(debug_body.find("LINGPET_RING_CORE_UPGRADE_CHOICE_ID") < 0, "debug setter should not pass ring-core constants inline")
	_expect(debug_body.find("LEVEL_FEEDBACK_TIMER") < 0, "debug setter should not pass feedback timers inline")
	_expect(debug_body.find("_level_side_effects") < 0, "debug setter should not pass level-side-effect helper inline")
	_expect(debug_body.find("_instant_rewards") < 0, "debug setter should not pass instant-reward helper inline")
	_expect(debug_body.find("_lingpet_rewards") < 0, "debug setter should not pass Lingpet helper inline")
	_expect(debug_body.find("build_grant_callbacks") < 0, "debug setter should not build callback maps inline")
	_expect(facade_body.find("_get_runtime_state_dict(runtime_state, \"runtime_skill_levels\")") >= 0, "debug facade should own runtime-level lookup")
	_expect(facade_body.find("DEFAULT_RING_CORE_CHOICE_ID") < 0, "debug facade should omit the retired ring-core default")
	_expect(facade_body.find("_get_level_feedback_timer") >= 0, "debug facade should own feedback timer lookup")
	_expect(facade_body.find("build_grant_callbacks_from_runtime_state(runtime_state)") >= 0, "debug facade should build callbacks internally")
	_expect(debug_body.find("_debug_grants.build_path") < 0, "debug setter should not consume debug path payloads directly")
	_expect(debug_body.find("_debug_grants.apply_choice_data_update") < 0, "debug setter should not patch debug choice data directly")
	_expect(debug_body.find("_debug_grants.build_runtime_level_patch_update") < 0, "debug setter should not build runtime-level patches directly")
	_expect(debug_body.find("_debug_grants.apply_runtime_level_patch") < 0, "debug setter should not apply runtime-level patches directly")
	_expect(debug_body.find("_debug_grants.apply_post_apply_for_perk") < 0, "debug setter should not apply post-debug updates directly")
	_expect(debug_body.find("clean_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID") < 0, "debug setter should not own ring-core id branch inline")
	_expect(debug_body.find("bool(data.get(\"is_instant\", false))") < 0, "debug setter should not own instant branch inline")
	_expect(debug_body.find("str(data.get(\"unlocks_skill\", \"\"))") < 0, "debug setter should not own unlock branch inline")
	_expect(debug_body.find("last_selected_id = clean_id") < 0, "debug setter should not repeat last-selected writes inline")
	_expect(debug_body.find("data[key] = patch[key]") < 0, "debug setter should not apply data patches inline")
	_expect(debug_body.find("_debug_grants.build_choice_data_patch") < 0, "debug setter should not compose data patches inline")
	_expect(debug_body.find("_debug_grants.apply_choice_data_patch") < 0, "debug setter should not apply data patches through the low-level API")
	_expect(debug_body.find("runtime_skill_levels[clean_id]") < 0, "debug setter should not write runtime levels inline")
	_expect(debug_body.find("last_selected_id = str(update") < 0, "debug setter should not apply post-update state inline")
	_expect(state_source.find("func _apply_debug_grant_post_apply") < 0, "state should not keep a debug post-apply wrapper")


func _expect_path(result: Dictionary, expected_path: String, accepted: bool, message: String) -> void:
	_expect(bool(result.get("accepted", false)) == accepted, "%s accepted flag" % message)
	_expect(str(result.get("path", "")) == expected_path, "%s path" % message)


func _patch(result: Dictionary) -> Dictionary:
	if not bool(result.get("accepted", false)):
		return {}
	var value: Variant = result.get("patch", {})
	if value is Dictionary:
		return value
	return {}


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _reset_grant_calls() -> void:
	_apply_choice_calls = 0
	_apply_unlock_choice_calls = 0
	_apply_level_side_effect_calls = 0
	_apply_feedback_calls = 0
	_sync_owner_calls = 0
	_last_choice_data.clear()


func _grant_callbacks() -> Dictionary:
	return {
		RuntimePerkDebugGrants.CALLBACK_BUILD_INSTANT_UPDATE: Callable(self, "_build_instant_update"),
		RuntimePerkDebugGrants.CALLBACK_BUILD_UNLOCK_UPDATE: Callable(self, "_build_unlock_update"),
		RuntimePerkDebugGrants.CALLBACK_BUILD_LEVEL_UPDATE: Callable(self, "_build_level_update"),
		RuntimePerkDebugGrants.CALLBACK_APPLY_CHOICE: Callable(self, "_apply_choice"),
		RuntimePerkDebugGrants.CALLBACK_APPLY_UNLOCK_CHOICE: Callable(self, "_apply_unlock_choice"),
		RuntimePerkDebugGrants.CALLBACK_APPLY_LEVEL_SIDE_EFFECT: Callable(self, "_apply_level_side_effect"),
		RuntimePerkDebugGrants.CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT: Callable(self, "_apply_choice_feedback_result"),
		RuntimePerkDebugGrants.CALLBACK_SYNC_OWNER: Callable(self, "_sync_owner"),
	}


func _build_instant_update(perk_id: String, _data: Dictionary) -> Dictionary:
	return {
		"accepted": perk_id != "",
		"current_level": 0,
		"next_level": 0,
	}


func _build_unlock_update(perk_id: String, target_level: int, _data: Dictionary) -> Dictionary:
	return {
		"accepted": perk_id != "",
		"current_level": 0,
		"next_level": target_level,
	}


func _build_level_update(perk_id: String, target_level: int, _data: Dictionary) -> Dictionary:
	return {
		"accepted": perk_id != "",
		"current_level": max(0, target_level - 1),
		"next_level": target_level,
		"feedback_text": "Lv.%d" % target_level,
	}


func _apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
	_apply_choice_calls += 1
	_last_choice_data = choice.duplicate(true)
	return true


func _apply_unlock_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
	_apply_unlock_choice_calls += 1
	_last_choice_data = choice.duplicate(true)
	return true


func _apply_level_side_effect(choice: Dictionary, _owner: Object, _registry: Object) -> void:
	_apply_level_side_effect_calls += 1
	_last_choice_data = choice.duplicate(true)


func _apply_choice_feedback_result(_result: Dictionary, _choice: Dictionary, _fallback_timer: float) -> bool:
	_apply_feedback_calls += 1
	return true


func _sync_owner(_owner: Object) -> void:
	_sync_owner_calls += 1


class FakeRuntimeState:
	extends RefCounted

	var last_selected_id := ""
	var runtime_skill_levels: Dictionary = {}
	var _level_side_effects: Object = FakeFacadeLevelSideEffects.new()
	var _instant_rewards: Object = FakeFacadeInstantRewards.new()
	var apply_choice_calls := 0
	var apply_unlock_choice_calls := 0
	var apply_level_side_effect_calls := 0
	var apply_feedback_calls := 0
	var sync_owner_calls := 0
	var last_feedback_timer := 0.0
	var last_choice_data: Dictionary = {}

	func reset_calls() -> void:
		apply_choice_calls = 0
		apply_unlock_choice_calls = 0
		apply_level_side_effect_calls = 0
		apply_feedback_calls = 0
		sync_owner_calls = 0
		last_feedback_timer = 0.0
		last_choice_data.clear()

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_choice_calls += 1
		last_choice_data = choice.duplicate(true)
		return true

	func _apply_unlock_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_unlock_choice_calls += 1
		last_choice_data = choice.duplicate(true)
		return true

	func _apply_level_side_effect(choice: Dictionary, _owner: Object, _registry: Object) -> void:
		apply_level_side_effect_calls += 1
		last_choice_data = choice.duplicate(true)

	func _apply_choice_feedback_result(_result: Dictionary, _choice: Dictionary, fallback_timer: float) -> bool:
		apply_feedback_calls += 1
		last_feedback_timer = fallback_timer
		return true

	func _sync_owner(_owner: Object) -> void:
		sync_owner_calls += 1


class FakeFacadeInstantRewards:
	extends RefCounted

	func build_debug_instant_choice_update(perk_id: String, _data: Dictionary) -> Dictionary:
		return {
			"accepted": perk_id != "",
			"current_level": 0,
			"next_level": 0,
		}


class FakeFacadeLevelSideEffects:
	extends RefCounted

	var LEVEL_FEEDBACK_TIMER := 1.7

	func build_debug_unlock_choice_update(perk_id: String, target_level: int, _data: Dictionary) -> Dictionary:
		return {
			"accepted": perk_id != "",
			"current_level": 0,
			"next_level": target_level,
		}

	func build_debug_level_update(perk_id: String, target_level: int, _data: Dictionary) -> Dictionary:
		return {
			"accepted": perk_id != "",
			"current_level": max(0, target_level - 1),
			"next_level": target_level,
			"feedback_text": "Lv.%d" % target_level,
		}


class FakeOwner:
	var sync_count := 0

	func sync_owner(_owner: Object) -> void:
		sync_count += 1


class FakeRegistry:
	extends RefCounted


class FakeLingpetRuntime:
	extends RefCounted

	var candidate_build_calls := 0

	func build_guardian_enhance_live_candidates(_owner: Object) -> Array:
		candidate_build_calls += 1
		return [{"type": "duration", "label": "지속시간 +5초"}]


class FakeLingpetRegistry:
	extends RefCounted

	var lingpet_runtime := FakeLingpetRuntime.new()

	func get_cached_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return lingpet_runtime
		return null


class FakeCatalog:
	extends RefCounted

	var data: Dictionary

	func _init(initial_data: Dictionary) -> void:
		data = initial_data

	func get_perk_data(perk_id: String) -> Dictionary:
		var value: Variant = data.get(perk_id, {})
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
		return {}
