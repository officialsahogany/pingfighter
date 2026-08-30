extends SceneTree

const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _reset_calls := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRuntimePerkState:
	extends RefCounted

	var capture_calls := 0
	var pause_calls := 0
	var resume_calls := 0
	var arm_calls := 0

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		capture_calls += 1

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		arm_calls += 1


class FakeAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_dash_delay() -> void:
		stop_calls += 1


class FakeResultScreen:
	extends RefCounted

	var show_calls := 0

	func show_from_scoreboard(
		_owner: Object,
		_registry: Object,
		_reset_callback: Callable,
		_exit_callback: Callable
	) -> bool:
		show_calls += 1
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


func _init() -> void:
	_verify_common_shell_and_localization_catalog()
	_verify_node_modal_opens_only_after_map_arrival()
	_verify_production_entry_lifecycle_and_exit()
	_verify_production_entry_fails_closed_without_runtime_contract()
	_verify_flag_off_preserves_legacy_path()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")


func _verify_node_modal_opens_only_after_map_arrival() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var map_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
		"guardian_spring"
	)
	_expect(
		map_seed > 0,
		"no map seed exposes a guardian_spring node in the first route row"
	)
	if map_seed <= 0:
		return
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "arrival-modal-contract",
		"map_seed": map_seed,
	}), "arrival-modal fixture must begin")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "victory completion must not open a node modal at the defeated boss")
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	var spring_index := -1
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == "guardian_spring":
			spring_index = index
			break
	_expect(spring_index >= 0, "the deterministic arrival fixture must expose a guardian-spring target")
	if spring_index < 0:
		return
	flow.debug_launch_at_target(spring_index)
	flow.update_selective(1.5)
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "target hit must show map movement before node work")
	var selected_id := flow.get_selected_target_id()
	flow.update_selective(1.0)
	_expect(flow.get_phase_name() == "NODE_MODAL", "noncombat work must open only after map movement reaches the node")
	_expect(flow.get_current_node_id() == selected_id, "arrival modal must belong to the node reached by the selected edge")
	_expect(flow.get_node_modal_kind() == "guardian_spring", "arrival must derive the modal kind from the selected graph node")
	var arrival_snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not arrival_snapshot.is_empty(), "the arrived node modal must remain a stable snapshot boundary")
	var generated_route_ids: Array = arrival_snapshot.get("route_target_ids", [])
	_expect(
		generated_route_ids.size() == 2,
		"the v18 first-route spring must publish both generated outgoing candidates"
	)
	var one_candidate_snapshot := arrival_snapshot.duplicate(true)
	if not generated_route_ids.is_empty():
		one_candidate_snapshot["route_target_ids"] = [str(generated_route_ids[0])]
	_expect(
		(one_candidate_snapshot.get("route_target_ids", []) as Array).size() == 1,
		"the availability-filtered restore fixture must retain one graph-backed candidate"
	)
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(one_candidate_snapshot), "a one-candidate arrived node modal must restore")
	_expect(restored.get_phase_name() == "NODE_MODAL", "restored arrival must reopen the reached node modal")
	_expect(
		(restored.export_persistable_snapshot().get("route_target_ids", []) as Array).size()
			== 1,
		"restored availability-filtered routing must remain a one-candidate boundary"
	)

	if _failures.is_empty():
		print("tower_ascent_node_modal_shell_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_common_shell_and_localization_catalog() -> void:
	var state := TowerAscentNodeModalState.new()
	state.open("node-a", "shop", {"gold": 91, "muhon": 12, "chance_gems": 2}, [{
		"id": "blocked_purchase",
		"label": "시험 상품",
		"enabled": false,
		"unavailable_reason": "금화 10 부족",
	}])
	var model: Dictionary = state.build_view_model()
	_expect(str(model.get("title", "")) == "상점", "node shell must resolve its title through the tower localization catalog")
	_expect(str(model.get("muhon_text", "")) == "무혼 12", "node shell must show the run muhon balance")
	_expect(str(model.get("gold_text", "")) == "금화 91", "node shell must show the localized run gold balance")
	var actions: Array = model.get("actions", [])
	_expect(actions.size() == 2, "node shell must append one shared end-work action")
	_expect(not bool((actions[0] as Dictionary).get("enabled", true)), "disabled actions must remain disabled")
	_expect(str((actions[0] as Dictionary).get("unavailable_reason", "")) == "금화 10 부족", "disabled actions must expose the shortage reason")
	_expect(str((actions[1] as Dictionary).get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK, "shared end-work action must be the final action")

	for text_value in TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(
		LanguageSettings.LANGUAGE_KOREAN,
		{}
	).values():
		_expect(not str(text_value).contains("—"), "new Korean modal copy must not contain an em dash")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(TowerAscentNodeModalLocalization.node_title("rest") == "Campfire", "campfire title must use its direct English translation")
	_expect(TowerAscentNodeModalLocalization.get_missing_translation_locales().has(LanguageSettings.LANGUAGE_ENGLISH), "the catalog must report untranslated supported locales")
	_verify_gold_locale_copy()
	LanguageSettings.set_test_locale_override("")


func _verify_gold_locale_copy() -> void:
	var expected := {
		LanguageSettings.LANGUAGE_KOREAN: ["금화 91", "91 금화", "금화 120 필요, 29 부족"],
		LanguageSettings.LANGUAGE_ENGLISH: ["Gold 91", "91 Gold", "Requires 120 Gold, 29 short"],
		LanguageSettings.LANGUAGE_CHINESE: ["金币 91", "91 金币", "需要 120 金币，还差 29"],
		LanguageSettings.LANGUAGE_JAPANESE: ["金貨 91", "91 金貨", "金貨が120必要、あと29"],
		LanguageSettings.LANGUAGE_SPANISH: ["Oro 91", "91 de oro", "Se necesitan 120 de oro, faltan 29"],
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: ["Ouro 91", "91 de ouro", "Requer 120 de ouro, faltam 29"],
		LanguageSettings.LANGUAGE_RUSSIAN: ["Золото: 91", "91 золота", "Нужно 120 золота, не хватает 29"],
	}
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var copy: Array = expected.get(locale, [])
		_expect(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_BALANCE_GOLD,
			{"amount": 91}
		) == str(copy[0]), "%s gold balance copy must use its locale block" % locale)
		_expect(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_GOLD,
			{"amount": 91}
		) == str(copy[1]), "%s gold cost copy must use its locale block" % locale)
		_expect(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_GOLD,
			{"required": 120, "shortfall": 29}
		) == str(copy[2]), "%s insufficient-gold copy must use its locale block" % locale)


func _verify_production_entry_lifecycle_and_exit() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_reset_calls = 0
	var flow := TowerAscentFlowOwner.new()
	var runtime_state := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var result_screen := FakeResultScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": runtime_state,
		"game_audio": audio,
		"stage_clear_result_screen": result_screen,
	}
	var owner := FakeOwner.new()
	var driver := BattleSceneMatchFlowDriver.new()
	driver.call(
		"_finish_victory_loot_phase",
		registry,
		Callable(self, "_on_reset"),
		owner
	)
	_expect(flow.is_active(), "the production victory continuation must open the tower route flow")
	_expect(flow.get_phase_name() == "ROUTE_AIM", "the production entry must stay in the battle scene at ROUTE_AIM")
	_expect(flow.blocks_battle_physics(), "the active route flow must physically block ordinary battle simulation")
	_expect(runtime_state.capture_calls == 1, "modal entry must capture pre-choice ball velocity once")
	_expect(runtime_state.pause_calls == 1, "modal entry must fan out skill, item, and wall-clock pause once")
	_expect(audio.stop_calls == 1, "modal entry must route through centralized gameplay-loop cleanup")
	_expect(str(flow.export_snapshot().get("node_modal_kind", "")) == "guardian_spring", "stable snapshots must own the active node-modal kind")
	_expect(not flow.begin_vertical_slice(owner, Callable(), {"registry": registry}), "active flow re-entry must be rejected")
	_expect(runtime_state.pause_calls == 1, "rejected re-entry must not pause cooldowns twice")

	_expect(runtime_state.resume_calls == 0, "cooldowns must remain paused through route aiming")
	flow.call("_finish_vertical_slice")
	_expect(not flow.is_active(), "map transition completion must close the tower flow")
	_expect(runtime_state.resume_calls == 1, "flow close must resume paused cooldowns exactly once")
	_expect(runtime_state.arm_calls == 1, "flow close must arm ball-freeze and score resume safety")
	_expect(result_screen.show_calls == 0, "tower flow close must never show the legacy result screen")
	_expect(_reset_calls == 1, "tower flow close must resume combat through the reset callback exactly once")


func _verify_production_entry_fails_closed_without_runtime_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_reset_calls = 0
	var flow := TowerAscentFlowOwner.new()
	var result_screen := FakeResultScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"stage_clear_result_screen": result_screen,
	}
	BattleSceneMatchFlowDriver.new().call(
		"_finish_victory_loot_phase",
		registry,
		Callable(self, "_on_reset"),
		FakeOwner.new()
	)
	_expect(not flow.is_active(), "production entry must fail closed without the modal lifecycle runtime")
	_expect(result_screen.show_calls == 0, "failed tower entry must not leak into the legacy result continuation")
	_expect(_reset_calls == 1, "failed tower entry must fail closed through the reset callback")
	_expect(flow.export_snapshot().completed_nodes.is_empty(), "failed lifecycle entry must not commit the prepared node reward")


func _verify_flag_off_preserves_legacy_path() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_reset_calls = 0
	var flow := TowerAscentFlowOwner.new()
	var runtime_state := FakeRuntimePerkState.new()
	var result_screen := FakeResultScreen.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow,
		"runtime_perk_state": runtime_state,
		"stage_clear_result_screen": result_screen,
	}
	BattleSceneMatchFlowDriver.new().call(
		"_finish_victory_loot_phase",
		registry,
		Callable(self, "_on_reset"),
		FakeOwner.new()
	)
	_expect(result_screen.show_calls == 1, "flag OFF must preserve the legacy result flow")
	_expect(_reset_calls == 0, "flag OFF result ownership must remain with the legacy screen")
	_expect(runtime_state.pause_calls == 0, "flag OFF must not enter the tower modal lifecycle")


func _on_reset() -> void:
	_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
