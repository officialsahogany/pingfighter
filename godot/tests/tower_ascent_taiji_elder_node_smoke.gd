extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTaijiElderNode := preload(
	"res://scripts/tower_ascent/tower_ascent_taiji_elder_node.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)

const NODE_KIND := "taiji_elder"
const ACTION_ACCEPT := "taiji_elder:accept"
const ACTION_DECLINE := "taiji_elder:decline"
const EXPECTED_DIALOGUE_TEMPLATES: Array[String] = [
	"내 나이가 여든이 넘었는데",
	"집안 대대로 내려오는 무공을 전수할 제자도 자식도 없으니..",
	"가만 보니 자네는 총명한 눈을 가졌군",
	"그대라면 .. 어쩌면 믿고 전수해줄 수 있을지도",
	"음 그런데 생각해보니 그냥 전수하기엔 좀 아깝고..",
	"자네가 익힌 '~'를 나에게 전이해줄 수 있나 ? 죽기전에 익혀보고싶은 무공이군 ..",
]
const EXPECTED_QUESTION := "교환하시겠습니까?"
const EXPECTED_YES := "네"
const EXPECTED_NO := "아니오"
const EXPECTED_YES_RESULT := "끌끌.. 그대의 여정에 도움이 되었기를..."
const EXPECTED_NO_RESULT := "이런.. 그대가 이 절세무공의 강함을 느껴보길 원했건만 .."
const LOCALIZATION_KEYS: Array[String] = [
	"tower_ascent.node_modal.taiji_elder.title",
	"tower_ascent.node_modal.taiji_elder.description",
	"tower_ascent.node_modal.taiji_elder.dialogue.age",
	"tower_ascent.node_modal.taiji_elder.dialogue.heir",
	"tower_ascent.node_modal.taiji_elder.dialogue.eyes",
	"tower_ascent.node_modal.taiji_elder.dialogue.trust",
	"tower_ascent.node_modal.taiji_elder.dialogue.cost",
	"tower_ascent.node_modal.taiji_elder.dialogue.request",
	"tower_ascent.node_modal.taiji_elder.question",
	"tower_ascent.node_modal.taiji_elder.accept",
	"tower_ascent.node_modal.taiji_elder.decline",
	"tower_ascent.node_modal.taiji_elder.result.accept",
	"tower_ascent.node_modal.taiji_elder.result.decline",
	"tower_ascent.node_modal.taiji_elder.unavailable.source",
	"tower_ascent.node_modal.taiji_elder.unavailable.target",
]

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	NODE_KIND
)


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var chance_gems_count := 0
	var chance_gems_max := 0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return get_instance(key)


class FakeUnlockStore:
	extends RefCounted

	var unlocked_ids: Dictionary = {}

	func is_unlocked(content_type: String, content_id: String) -> bool:
		return (
			content_type == "runtime_perk"
			and bool(unlocked_ids.get(content_id, false))
		)


func _initialize() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_actual_arrival_pair_rng_copy_and_restore()
	_verify_pointer_dialogue_single_step()
	_verify_legacy_snapshot_without_taiji_fields_restores()
	_verify_core_determinism_domains_atomicity_and_fail_safes()
	_verify_source_type_exclusions()
	_verify_direct_localization_keys()
	_verify_map_localization_and_art_gap()
	LanguageSettings.set_test_locale_override("")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
	if _failures.is_empty():
		print("tower_taiji_elder_n3_node_seal: arrival=1 pair_deterministic=1 pools_sorted=1 authority_rng_unchanged=1 rng_domains_independent=1 ko_copy=6 locales=7 map_locales=7 yes_atomic=1 owner_raw_projection=1 failure_retry=2 decline_noop=1 result_hold=2 result_hold_persist=1 fresh_runtime_restore=1 fresh_owner_raw_projection=1 history_restore=1 pair_no_reroll=1 decline_build_noop=1 zero_pool=2 restore_mid_modal=1 legacy_missing_fields=1 pointer_pairs=2 duplicate_noop=1 source_exclusions=9 fusion_hidden=1 icon_unmapped_fallback=1")
		print("tower_ascent_taiji_elder_node_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_actual_arrival_pair_rng_copy_and_restore() -> void:
	_expect(_initial_route_seed > 0, "Taiji Elder must be reachable through a generated initial route")
	var fixture := _build_fixture({
		"common_swiftness": 3,
		"common_bulk_up": 2,
		"item_luck": 2,
		"dash_acceleration": 3,
		"item_gauge_mastery": 2,
	})
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	var state: Object = fixture.state
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "taiji-actual-arrival",
		"map_seed": _initial_route_seed,
		"node_modal_kind": NODE_KIND,
		"registry": registry,
	}), "Taiji Elder fixture must begin through the production Tower flow")
	var arrival := _advance_to_taiji_modal_with_rng_seal(flow, owner)
	_expect(bool(arrival.get("arrived", false)), "Taiji Elder must open only after real map arrival")
	_expect(
		var_to_bytes(arrival.get("rng_before", {}))
		== var_to_bytes(arrival.get("rng_after", {})),
		"Taiji presentation pair generation must leave gameplay_rng_state byte-identical"
	)
	var presentation := _presentation(flow)
	_assert_offer_snapshot(presentation, fixture.catalog)
	_expect(str(presentation.get("phase", "")) == "dialogue", "arrival must start at dialogue phase")
	_expect(int(presentation.get("dialogue_index", -1)) == 0, "arrival must start at dialogue line zero")
	var premature := flow.execute_node_action(ACTION_ACCEPT, "taiji:premature")
	_expect(
		not bool(premature.get("accepted", true))
		and str(premature.get("reason", "")) == "taiji_elder_sequence_incomplete",
		"direct exchange must fail closed before all six dialogue lines"
	)
	for expected_index in range(3):
		var step := _presentation(flow)
		_expect(int(step.get("dialogue_index", -1)) == expected_index, "dialogue index must advance in canonical order")
		_expect(str(step.get("current_dialogue", "")) == _expected_dialogue(step, expected_index), "visible dialogue must preserve exact canonical line order")
		_press_accept(flow, owner)
	var mid_snapshot := flow.export_persistable_snapshot()
	_expect(not mid_snapshot.is_empty(), "mid-dialogue Taiji modal must be persistable")
	var mid_build_state: Dictionary = (mid_snapshot.get("build_state", {}) as Dictionary).duplicate(true)
	mid_build_state["runtime_perk_snapshot"] = state.build_unlock_save_snapshot()
	mid_snapshot["build_state"] = mid_build_state
	var mid_pair := _pair(_presentation(flow))
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(mid_snapshot, Callable(), owner, registry), "mid-dialogue Taiji modal must restore")
	var restored_presentation := _presentation(restored)
	_expect(_pair(restored_presentation) == mid_pair, "restore must retain the stored source and mythic pair without reroll")
	_expect(str(restored_presentation.get("phase", "")) == "dialogue" and int(restored_presentation.get("dialogue_index", -1)) == 3, "restore must retain the exact mid-modal phase and dialogue index")
	for expected_index in range(3, EXPECTED_DIALOGUE_TEMPLATES.size()):
		var step := _presentation(restored)
		_expect(str(step.get("current_dialogue", "")) == _expected_dialogue(step, expected_index), "restored dialogue must resume without skipping or rerolling")
		_press_accept(restored, owner)
	var decision := _presentation(restored)
	_expect(str(decision.get("phase", "")) == "decision", "sixth dialogue must reveal the exchange decision")
	_expect(str(decision.get("question", "")) == EXPECTED_QUESTION, "decision must preserve the exact Korean question")
	var actions: Array = restored.get_node_modal_view_model().get("actions", [])
	_expect(_action_ids(actions) == [ACTION_ACCEPT, ACTION_DECLINE], "decision actions must be accept then decline")
	if actions.size() == 2:
		_expect(str(actions[0].get("label", "")) == EXPECTED_YES and str(actions[1].get("label", "")) == EXPECTED_NO, "decision actions must display exact 네 and 아니오 labels")
	else:
		_expect(false, "decision must expose exactly two label-bearing actions")
	var source_id := str(decision.get("source_id", ""))
	var target_id := str(decision.get("target_id", ""))
	var unrelated_before: Dictionary = state.runtime_skill_levels.duplicate(true)
	var yes_result := restored.execute_node_action(ACTION_ACCEPT, "taiji:accept-once")
	_expect(bool(yes_result.get("applied", false)), "yes must execute the actual whole-card exchange")
	_expect(int(state.runtime_skill_levels.get(source_id, 0)) == 0, "yes must remove the entire selected source card")
	_expect(int(state.runtime_skill_levels.get(target_id, 0)) == 1, "yes must grant the stored mythic at level one")
	_expect(owner.runtime_perk_levels == state.runtime_skill_levels, "yes success must publish source zero and target level one to the owner raw projection")
	for perk_id_value in unrelated_before.keys():
		var perk_id := str(perk_id_value)
		if perk_id != source_id:
			_expect(int(state.runtime_skill_levels.get(perk_id, 0)) == int(unrelated_before.get(perk_id, 0)), "yes must preserve every unrelated martial art")
	_expect(_contains_text(restored.get_node_modal_view_model(), EXPECTED_YES_RESULT), "yes result must be visibly presented before route exit")
	_expect(restored.get_phase_name() == "NODE_MODAL", "yes result must remain in the modal for presentation")
	restored.update_selective(0.10, owner)
	_expect(restored.get_phase_name() == "NODE_MODAL" and _contains_text(restored.get_node_modal_view_model(), EXPECTED_YES_RESULT), "yes result must remain visible through the minimum hold")
	var yes_snapshot: Dictionary = restored.export_persistable_snapshot()
	_expect(not yes_snapshot.is_empty(), "yes result hold must be a persistable stable boundary")
	var expected_restored_levels := unrelated_before.duplicate(true)
	expected_restored_levels.erase(source_id)
	expected_restored_levels[target_id] = 1
	var yes_build_state: Dictionary = yes_snapshot.get("build_state", {}) as Dictionary
	var yes_runtime_snapshot: Dictionary = yes_build_state.get("runtime_perk_snapshot", {}) as Dictionary
	_expect(
		(yes_runtime_snapshot.get("runtime_skill_levels", {}) as Dictionary) == expected_restored_levels,
		"yes result snapshot must capture the committed source removal and level-one mythic grant"
	)
	var fresh_fixture := _build_fixture({"common_bulk_up": 99})
	var fresh_restored := TowerAscentFlowOwner.new()
	_expect(
		fresh_restored.restore_snapshot(
			yes_snapshot,
			Callable(),
			fresh_fixture.owner,
			fresh_fixture.registry
		),
		"yes result snapshot must restore into a fresh runtime owner"
	)
	_expect(
		fresh_fixture.state.runtime_skill_levels == expected_restored_levels,
		"fresh yes restore must retain source zero, target level one, and every unrelated level"
	)
	_expect(
		fresh_fixture.owner.runtime_perk_levels == fresh_fixture.state.runtime_skill_levels,
		"fresh yes restore owner raw projection must exactly match the restored runtime state"
	)
	var fresh_snapshot: Dictionary = fresh_restored.export_persistable_snapshot()
	var fresh_taiji_state: Dictionary = fresh_snapshot.get("taiji_elder_state", {}) as Dictionary
	_expect(
		(fresh_taiji_state.get("history", []) as Array).size() == 1,
		"fresh yes restore must retain the single committed Taiji history record"
	)
	_expect(
		_pair(_presentation(fresh_restored)) == {"source_id": source_id, "target_id": target_id},
		"fresh yes restore must retain the exact stored pair without reroll"
	)
	var after_yes: Dictionary = state.build_tower_reward_mutation_snapshot()
	var duplicate := restored.execute_node_action(ACTION_ACCEPT, "taiji:accept-once")
	_expect(
		str(duplicate.get("reason", "")) == "already_committed"
		and var_to_bytes(state.build_tower_reward_mutation_snapshot()) == var_to_bytes(after_yes),
		"duplicate resolution id must be an explicit mutation-free no-op"
	)
	_advance_result_to_route(restored, owner, "yes")

	var decline_fixture := _build_fixture({"common_swiftness": 3, "item_luck": 2, "dash_acceleration": 3})
	var decline_flow := _arrived_flow(decline_fixture, "taiji-decline")
	_advance_all_dialogue(decline_flow, decline_fixture.owner)
	var decline_seed_snapshot: Dictionary = decline_flow.export_persistable_snapshot()
	var decline_seed_build: Dictionary = (decline_seed_snapshot.get("build_state", {}) as Dictionary).duplicate(true)
	decline_seed_build["runtime_perk_snapshot"] = decline_fixture.state.build_unlock_save_snapshot()
	decline_seed_snapshot["build_state"] = decline_seed_build
	var decline_restored := TowerAscentFlowOwner.new()
	_expect(
		decline_restored.restore_snapshot(
			decline_seed_snapshot,
			Callable(),
			decline_fixture.owner,
			decline_fixture.registry
		),
		"decline fixture with an existing runtime build snapshot must restore"
	)
	decline_flow = decline_restored
	var decline_before: Dictionary = decline_fixture.state.build_tower_reward_mutation_snapshot()
	var decline_build_before := var_to_bytes(
		(decline_flow.export_persistable_snapshot().get("build_state", {}) as Dictionary)
	)
	var declined: Dictionary = decline_flow.execute_node_action(ACTION_DECLINE, "taiji:decline-once")
	_expect(bool(declined.get("choice_committed", false)) and not bool(declined.get("accepted_exchange", true)), "decline must commit only the node choice")
	_expect(var_to_bytes(decline_fixture.state.build_tower_reward_mutation_snapshot()) == var_to_bytes(decline_before), "decline must leave all martial state byte-identical")
	_expect(
		var_to_bytes(decline_flow.export_persistable_snapshot().get("build_state", {}))
		== decline_build_before,
		"decline must leave the persisted runtime build snapshot byte-identical"
	)
	_expect(_contains_text(decline_flow.get_node_modal_view_model(), EXPECTED_NO_RESULT), "decline result must preserve exact Korean copy")
	decline_flow.update_selective(0.10, decline_fixture.owner)
	_expect(decline_flow.get_phase_name() == "NODE_MODAL" and _contains_text(decline_flow.get_node_modal_view_model(), EXPECTED_NO_RESULT), "decline result must remain visible through the minimum hold")
	_advance_result_to_route(decline_flow, decline_fixture.owner, "decline")


func _verify_pointer_dialogue_single_step() -> void:
	var fixture := _build_fixture({"item_luck": 2, "dash_acceleration": 3})
	var flow := _arrived_flow(fixture, "taiji-pointer-dialogue")
	var dialogue_point := Vector2(380.0, 560.0)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 0, "pointer fixture must start at dialogue line zero")

	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.position = dialogue_point
	mouse_press.pressed = true
	flow.handle_input(mouse_press)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 0, "mouse press alone must not advance Taiji dialogue")
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.position = dialogue_point
	mouse_release.pressed = false
	flow.handle_input(mouse_release)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 1, "one mouse press-release pair must advance exactly one Taiji line")
	flow.handle_input(mouse_release)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 1, "unarmed mouse release must not advance another Taiji line")

	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = dialogue_point
	touch_press.pressed = true
	flow.handle_input(touch_press)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 1, "touch press alone must not advance Taiji dialogue")
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.position = dialogue_point
	touch_release.pressed = false
	flow.handle_input(touch_release)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 2, "one touch press-release pair must advance exactly one Taiji line")
	flow.handle_input(touch_release)
	_expect(int(_presentation(flow).get("dialogue_index", -1)) == 2, "unarmed touch release must not advance another Taiji line")


func _verify_legacy_snapshot_without_taiji_fields_restores() -> void:
	var fixture := _build_fixture({"item_luck": 2, "dash_acceleration": 3})
	var original := TowerAscentFlowOwner.new()
	_expect(original.begin_vertical_slice(fixture.owner, Callable(), {
		"run_id": "taiji-legacy-snapshot",
		"map_seed": _initial_route_seed,
		"node_modal_kind": NODE_KIND,
		"registry": fixture.registry,
	}), "legacy compatibility fixture must begin")
	var target_index := -1
	var targets: Array[Dictionary] = original.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == NODE_KIND:
			target_index = index
			break
	_expect(target_index >= 0, "legacy compatibility fixture must expose a Taiji route target")
	if target_index < 0:
		return
	original.debug_launch_at_target(target_index)
	original.update_selective(
		TowerAscentNodeArrivalTestFixture.REFERENCE_FLIGHT_SECONDS
		* TowerAscentNodeArrivalTestFixture.REFERENCE_SERVE_SPEED_PER_SECOND
		/ maxf(1.0, TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND),
		fixture.owner
	)
	_expect(original.get_phase_name() == "MAP_TRANSITION", "legacy compatibility snapshot must be captured at a stable transition boundary")
	var current: Dictionary = original.export_persistable_snapshot()
	_expect(current.has("taiji_elder_state") and current.has("taiji_elder_presentation_state"), "current snapshots must own Taiji core and presentation fields")
	var legacy: Dictionary = current.duplicate(true)
	legacy.erase("taiji_elder_state")
	legacy.erase("taiji_elder_history")
	legacy.erase("taiji_elder_presentation_state")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(legacy, Callable(), fixture.owner, fixture.registry), "legacy snapshot without Taiji core or presentation fields must restore successfully")
	_expect(restored.get_phase_name() == original.get_phase_name(), "legacy Taiji-field omission must preserve the stored flow phase")
	var restored_snapshot: Dictionary = restored.export_persistable_snapshot()
	_expect((restored_snapshot.get("taiji_elder_history", []) as Array).is_empty(), "legacy restore must initialize empty Taiji history")
	var restored_taiji: Dictionary = restored_snapshot.get("taiji_elder_state", {}) as Dictionary
	_expect((restored_taiji.get("generated_pairs", []) as Array).is_empty(), "legacy restore must initialize empty Taiji generated-pair state")


func _verify_core_determinism_domains_atomicity_and_fail_safes() -> void:
	var fixture := _build_fixture({"common_swiftness": 4, "item_luck": 2, "dash_acceleration": 3})
	var first: Object = TowerAscentTaijiElderNode.new()
	var second: Object = TowerAscentTaijiElderNode.new()
	seed(81173)
	var expected_global := randf()
	seed(81173)
	var first_begin: Dictionary = first.begin_visit("taiji-core", 912731, fixture.owner, fixture.registry, fixture.catalog)
	var actual_global := randf()
	var second_begin: Dictionary = second.begin_visit("taiji-core", 912731, fixture.owner, fixture.registry, fixture.catalog)
	_expect(bool(first_begin.get("accepted", false)) and bool(second_begin.get("accepted", false)), "core begin_visit must accept an eligible visit")
	_expect(is_equal_approx(actual_global, expected_global), "core offer generation must not consume global RNG")
	var first_modal: Dictionary = first.get_modal_snapshot("taiji-core")
	var second_modal: Dictionary = second.get_modal_snapshot("taiji-core")
	_expect(_strings(first_modal.get("eligible_source_ids", [])).size() == 2, "same-seed designation fixture must contain two genuinely visible ordinary sources")
	_expect(_pair(first_modal) == _pair(second_modal), "same seed and node id must store the same source and mythic pair")
	_expect(var_to_bytes(first.build_save_snapshot()) == var_to_bytes(second.build_save_snapshot()), "same deterministic visit must serialize byte-identically")
	_expect(_strings(first_modal.get("eligible_source_ids", [])) == _sorted_strings(first_modal.get("eligible_source_ids", [])), "eligible source pool must be sorted before deterministic selection")
	_expect(_strings(first_modal.get("eligible_target_ids", [])) == _sorted_strings(first_modal.get("eligible_target_ids", [])), "eligible target pool must be sorted before deterministic selection")
	_expect(int(first_modal.get("generation", -1)) == 0, "initial deterministic offer generation must be zero")

	var source_expanded := _build_fixture({"common_swiftness": 4, "item_luck": 2, "dash_acceleration": 3, "item_gauge_mastery": 1})
	var source_domain: Object = TowerAscentTaijiElderNode.new()
	source_domain.begin_visit("taiji-core", 912731, source_expanded.owner, source_expanded.registry, source_expanded.catalog)
	var source_expanded_modal: Dictionary = source_domain.get_modal_snapshot("taiji-core")
	_expect(_strings(source_expanded_modal.get("eligible_source_ids", [])).size() == _strings(first_modal.get("eligible_source_ids", [])).size() + 1, "source-domain counterproof must really add one visible ordinary source")
	_expect(str(source_expanded_modal.get("target_id", "")) == str(first_modal.get("target_id", "")), "changing only the source pool must not perturb the target RNG domain")
	var target_expanded := _build_fixture({"common_swiftness": 4, "item_luck": 2, "dash_acceleration": 3}, true)
	var target_domain: Object = TowerAscentTaijiElderNode.new()
	target_domain.begin_visit("taiji-core", 912731, target_expanded.owner, target_expanded.registry, target_expanded.catalog)
	var target_expanded_modal: Dictionary = target_domain.get_modal_snapshot("taiji-core")
	_expect(_strings(target_expanded_modal.get("eligible_target_ids", [])).size() == _strings(first_modal.get("eligible_target_ids", [])).size() + 1, "target-domain counterproof must really add one unlocked mythic target")
	_expect(str(target_expanded_modal.get("source_id", "")) == str(first_modal.get("source_id", "")), "changing only the target pool must not perturb the source RNG domain")

	var saved: Dictionary = first.build_save_snapshot()
	var restored: Object = TowerAscentTaijiElderNode.new()
	var restore_result: Dictionary = restored.restore_save_snapshot(saved)
	_expect(bool(restore_result.get("restored", false)) and _pair(restored.get_modal_snapshot("taiji-core")) == _pair(first_modal), "core save restore must retain the stored pair without reroll")
	var empty_restored: Object = TowerAscentTaijiElderNode.new()
	var empty_restore_result: Dictionary = empty_restored.restore_save_snapshot({})
	var empty_snapshot: Dictionary = empty_restored.build_save_snapshot()
	_expect(bool(empty_restore_result.get("restored", false)) and bool(empty_restore_result.get("empty", false)), "core empty legacy state must restore as an accepted no-state snapshot")
	_expect((empty_snapshot.get("generated_pairs", []) as Array).is_empty() and (empty_snapshot.get("history", []) as Array).is_empty() and (empty_snapshot.get("resolutions", {}) as Dictionary).is_empty(), "core empty legacy restore must initialize all Taiji state collections empty")

	var rejection_node: Object = TowerAscentTaijiElderNode.new()
	rejection_node.begin_visit("taiji-reject", 32177, fixture.owner, fixture.registry, fixture.catalog)
	rejection_node.mark_confirmation_ready("taiji-reject")
	var rejection_before: Dictionary = fixture.state.build_tower_reward_mutation_snapshot()
	var rejection_ids: Dictionary = {}
	var rejected: Dictionary = rejection_node.resolve_exchange(true, "taiji:reject", "taiji-reject", rejection_ids, fixture.owner, fixture.registry, fixture.catalog, {"force_grant_rejection": true})
	_expect(str(rejected.get("reason", rejected.get("blocked_reason", ""))) == "taiji_exchange_choice_rejected", "injected grant rejection must reach the production precommit gate")
	_expect(_mutation_semantics(fixture.state.build_tower_reward_mutation_snapshot()) == _mutation_semantics(rejection_before), "grant rejection must remain mutation-free before either exchange leg commits")
	var rejection_modal: Dictionary = rejection_node.get_modal_snapshot("taiji-reject")
	_expect(rejection_ids.is_empty() and not bool(rejection_modal.get("choice_committed", false)) and not bool(rejection_modal.get("resolved", false)), "grant rejection must leave history, resolution, and completion empty")
	var retried: Dictionary = rejection_node.resolve_exchange(true, "taiji:reject-retry", "taiji-reject", rejection_ids, fixture.owner, fixture.registry, fixture.catalog)
	_expect(bool(retried.get("applied", false)) and rejection_ids.has("taiji:reject-retry"), "grant rejection must leave the same stored pair retryable")

	var post_fixture := _build_fixture({"common_swiftness": 4, "item_luck": 2, "dash_acceleration": 3})
	var post_node: Object = TowerAscentTaijiElderNode.new()
	post_node.begin_visit("taiji-post", 32179, post_fixture.owner, post_fixture.registry, post_fixture.catalog)
	post_node.mark_confirmation_ready("taiji-post")
	var post_before: Dictionary = post_fixture.state.build_tower_reward_mutation_snapshot()
	var post_ids: Dictionary = {}
	var post_failed: Dictionary = post_node.resolve_exchange(true, "taiji:post", "taiji-post", post_ids, post_fixture.owner, post_fixture.registry, post_fixture.catalog, {"force_postcondition_failure": true})
	_expect(str(post_failed.get("reason", post_failed.get("blocked_reason", ""))) == "taiji_exchange_postcondition_failed", "postcondition counterproof must fail at the production precommit validation gate")
	_expect(_mutation_semantics(post_fixture.state.build_tower_reward_mutation_snapshot()) == _mutation_semantics(post_before), "postcondition failure must leave both exchange legs mutation-free")
	var post_modal: Dictionary = post_node.get_modal_snapshot("taiji-post")
	_expect(post_ids.is_empty() and not bool(post_modal.get("choice_committed", false)) and not bool(post_modal.get("resolved", false)), "postcondition failure must leave history, resolution, and completion empty")
	var post_retry: Dictionary = post_node.resolve_exchange(true, "taiji:post-retry", "taiji-post", post_ids, post_fixture.owner, post_fixture.registry, post_fixture.catalog)
	_expect(bool(post_retry.get("applied", false)) and post_ids.has("taiji:post-retry"), "postcondition rollback must leave the stored pair retryable")

	var no_source := _build_fixture({})
	var no_source_node: Object = TowerAscentTaijiElderNode.new()
	no_source_node.begin_visit("taiji-no-source", 7, no_source.owner, no_source.registry, no_source.catalog)
	var no_source_modal: Dictionary = no_source_node.get_modal_snapshot("taiji-no-source")
	_expect(not bool(no_source_modal.get("available", true)) and bool(no_source_modal.get("auto_resolve", false)), "zero eligible sources must fail safe without an exchange")
	var no_target := _build_fixture({"item_luck": 1}, false, true)
	var no_target_node: Object = TowerAscentTaijiElderNode.new()
	no_target_node.begin_visit("taiji-no-target", 7, no_target.owner, no_target.registry, no_target.catalog)
	var no_target_modal: Dictionary = no_target_node.get_modal_snapshot("taiji-no-target")
	_expect(not bool(no_target_modal.get("available", true)) and bool(no_target_modal.get("auto_resolve", false)), "zero eligible mythic targets must fail safe without an exchange")

	var fusion_fixture := _build_fixture({"common_swiftness": 1, "item_luck": 3, "common_bulk_up": 5})
	var fusion_record: Dictionary = fusion_fixture.state.commit_perk_fusion(["item_luck", "common_bulk_up"], {"outcome": "success"}, fusion_fixture.catalog)
	_expect(not fusion_record.is_empty(), "fusion-hidden exclusion fixture must commit")
	var fusion_node: Object = TowerAscentTaijiElderNode.new()
	fusion_node.begin_visit("taiji-fusion", 55, fusion_fixture.owner, fusion_fixture.registry, fusion_fixture.catalog)
	var fusion_sources := _strings(fusion_node.get_modal_snapshot("taiji-fusion").get("eligible_source_ids", []))
	_expect("item_luck" not in fusion_sources and "common_bulk_up" not in fusion_sources, "fusion-hidden source cards must be excluded from the visible exchange pool")


func _verify_source_type_exclusions() -> void:
	var excluded_ids: Array[String] = [
		"angel_blessing",
		"unlock_magnum_grip",
		"common_swiftness",
		"physique_posture",
		"instant_gauge_full",
		"convert_to_gold",
		"mystic_dice",
		"lingpet_guardian_enhance",
		"jetpack_enhance",
	]
	var levels := {"item_luck": 2}
	for excluded_id in excluded_ids:
		levels[excluded_id] = 1
	var fixture := _build_fixture(levels)
	var node: Object = TowerAscentTaijiElderNode.new()
	node.begin_visit("taiji-source-filter", 66731, fixture.owner, fixture.registry, fixture.catalog)
	var sources := _strings(node.get_modal_snapshot("taiji-source-filter").get("eligible_source_ids", []))
	_expect("item_luck" in sources, "ordinary owned martial art must remain eligible")
	for excluded_id in excluded_ids:
		_expect(excluded_id not in sources, "source pool must exclude non-ordinary or wrong-character id %s" % excluded_id)


func _verify_direct_localization_keys() -> void:
	var korean_expected := {
		LOCALIZATION_KEYS[2]: EXPECTED_DIALOGUE_TEMPLATES[0],
		LOCALIZATION_KEYS[3]: EXPECTED_DIALOGUE_TEMPLATES[1],
		LOCALIZATION_KEYS[4]: EXPECTED_DIALOGUE_TEMPLATES[2],
		LOCALIZATION_KEYS[5]: EXPECTED_DIALOGUE_TEMPLATES[3],
		LOCALIZATION_KEYS[6]: EXPECTED_DIALOGUE_TEMPLATES[4],
		LOCALIZATION_KEYS[7]: EXPECTED_DIALOGUE_TEMPLATES[5],
		LOCALIZATION_KEYS[8]: EXPECTED_QUESTION,
		LOCALIZATION_KEYS[9]: EXPECTED_YES,
		LOCALIZATION_KEYS[10]: EXPECTED_NO,
		LOCALIZATION_KEYS[11]: EXPECTED_YES_RESULT,
		LOCALIZATION_KEYS[12]: EXPECTED_NO_RESULT,
	}
	var korean: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	for key in korean_expected:
		_expect(str(korean.get(key, "")) == str(korean_expected[key]), "Korean Taiji copy must preserve the canonical literal for %s" % key)
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		var locale_text: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(locale, {})
		for key in LOCALIZATION_KEYS:
			_expect(locale_text.has(key) and not str(locale_text.get(key, "")).is_empty(), "Taiji key %s must have a direct non-fallback translation for locale %s" % [key, locale])
			_expect(not str(locale_text.get(key, "")).contains(String.chr(0x2014)), "Taiji copy must not introduce an em dash for locale %s" % locale)


func _verify_map_localization_and_art_gap() -> void:
	var map_key := "tower_ascent.map_overlay.node.taiji_elder"
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		var locale_text: Dictionary = TowerAscentMapOverlayLocalization.TEXT_BY_LOCALE.get(locale, {})
		_expect(locale_text.has(map_key) and not str(locale_text.get(map_key, "")).is_empty(), "Taiji map label must have a direct non-fallback translation for locale %s" % locale)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_expect(str(TowerAscentMapOverlayLocalization.TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {}).get(map_key, "")) == "태극노인", "Taiji map label must preserve exact Korean copy")
	_expect(TowerAscentMapOverlayLocalization.node_kind_label(NODE_KIND) == "태극노인", "map node kind must route to the direct Taiji label key")
	var iconography := TowerAscentMapIconography.new()
	_expect(iconography.resolve_icon_path(NODE_KIND).is_empty(), "Taiji icon must remain intentionally unmapped until art routing supplies a bitmap")
	var fallback: Dictionary = iconography.resolve_presentation(NODE_KIND, "", "태극노인")
	_expect(str(fallback.get("icon_path", "")).is_empty() and fallback.get("icon_texture", null) == null and str(fallback.get("fallback_label", "")) == "태극노인", "missing Taiji bitmap must retain the exact label fallback")


func _build_fixture(
	levels: Dictionary,
	include_fourth_target: bool = false,
	no_targets: bool = false
) -> Dictionary:
	var owner := FakeOwner.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = levels.duplicate(true)
	var catalog: Object = RuntimePerkCatalog.new()
	var unlock_store := FakeUnlockStore.new()
	if not no_targets:
		unlock_store.unlocked_ids = {
			"angel_blessing": true,
			"baal_boots": true,
			"celestial_armor": include_fourth_target,
		}
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
		"tower_ascent_unlock_store": unlock_store,
	}
	return {
		"owner": owner,
		"state": state,
		"catalog": catalog,
		"registry": registry,
		"unlock_store": unlock_store,
	}


func _arrived_flow(fixture: Dictionary, run_id: String) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(fixture.owner, Callable(), {
		"run_id": run_id,
		"map_seed": _initial_route_seed,
		"node_modal_kind": NODE_KIND,
		"registry": fixture.registry,
	}), "%s must begin" % run_id)
	_expect(bool(_advance_to_taiji_modal_with_rng_seal(flow, fixture.owner).get("arrived", false)), "%s must arrive at Taiji Elder" % run_id)
	return flow


func _advance_to_taiji_modal_with_rng_seal(flow: Object, owner: Object) -> Dictionary:
	if flow == null or str(flow.get_phase_name()) != "ROUTE_AIM":
		return {"arrived": false}
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == NODE_KIND:
			target_index = index
			break
	if target_index < 0:
		return {"arrived": false}
	flow.debug_launch_at_target(target_index)
	flow.update_selective(
		TowerAscentNodeArrivalTestFixture.REFERENCE_FLIGHT_SECONDS
		* TowerAscentNodeArrivalTestFixture.REFERENCE_SERVE_SPEED_PER_SECOND
		/ maxf(1.0, TowerAscentTuning.TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND),
		owner
	)
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return {"arrived": false}
	var before: Dictionary = flow.export_persistable_snapshot()
	flow.update_selective(1.0, owner)
	var after: Dictionary = flow.export_persistable_snapshot()
	return {
		"arrived": str(flow.get_phase_name()) == "NODE_MODAL" and str(flow.get_node_modal_kind()) == NODE_KIND,
		"rng_before": before.get("gameplay_rng_state", {}).duplicate(true),
		"rng_after": after.get("gameplay_rng_state", {}).duplicate(true),
	}


func _presentation(flow: Object) -> Dictionary:
	var value: Variant = flow.get_node_modal_view_model().get("taiji_elder_presentation", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _assert_offer_snapshot(snapshot: Dictionary, catalog: Object) -> void:
	_expect(bool(snapshot.get("available", false)), "eligible arrival must expose one stored exchange pair")
	_expect(not str(snapshot.get("source_id", "")).is_empty() and not str(snapshot.get("target_id", "")).is_empty(), "stored pair must contain source and mythic ids")
	var source_name := str(catalog.get_perk_data(str(snapshot.get("source_id", ""))).get("name", ""))
	var expected_lines := EXPECTED_DIALOGUE_TEMPLATES.duplicate()
	expected_lines[5] = EXPECTED_DIALOGUE_TEMPLATES[5].replace("~", source_name)
	_expect(_strings(snapshot.get("dialogue_lines", [])) == expected_lines, "modal must store all six canonical lines with only ~ replaced")
	_expect(not str(expected_lines[5]).contains("~") and str(expected_lines[5]).contains("'%s'" % source_name), "sixth line must substitute the selected source name inside the retained quotes")


func _expected_dialogue(snapshot: Dictionary, index: int) -> String:
	var lines := _strings(snapshot.get("dialogue_lines", []))
	return lines[index] if index >= 0 and index < lines.size() else ""


func _pair(snapshot: Dictionary) -> Dictionary:
	return {
		"source_id": str(snapshot.get("source_id", "")),
		"target_id": str(snapshot.get("target_id", "")),
	}


func _press_accept(flow: Object, owner: Object) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	flow.handle_input(press)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.physical_keycode = KEY_ENTER
	release.pressed = false
	flow.handle_input(release)
	flow.update_selective(0.01, owner)


func _advance_all_dialogue(flow: Object, owner: Object) -> void:
	for _index in range(EXPECTED_DIALOGUE_TEMPLATES.size()):
		_press_accept(flow, owner)


func _advance_result_to_route(flow: Object, owner: Object, outcome: String) -> void:
	for _step in range(6):
		flow.update_selective(0.50, owner)
		if str(flow.get_phase_name()) != "NODE_MODAL":
			break
	_expect(str(flow.get_phase_name()) == "ROUTE_AIM", "held %s result must end at route selection" % outcome)


func _action_ids(actions: Array) -> Array[String]:
	var result: Array[String] = []
	for value in actions:
		if value is Dictionary:
			result.append(str((value as Dictionary).get("id", "")))
	return result


func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for child in value as Array:
			result.append(str(child))
	return result


func _sorted_strings(value: Variant) -> Array[String]:
	var result := _strings(value)
	result.sort()
	return result


func _contains_text(value: Variant, expected: String) -> bool:
	if value is String:
		return str(value) == expected
	if value is Dictionary:
		for child in (value as Dictionary).values():
			if _contains_text(child, expected):
				return true
	if value is Array:
		for child in value as Array:
			if _contains_text(child, expected):
				return true
	return false


func _mutation_semantics(snapshot: Dictionary) -> Dictionary:
	var unlock_snapshot: Dictionary = snapshot.get("unlock_save", {}) as Dictionary
	var training_snapshot: Dictionary = unlock_snapshot.get("physique_training", {}) as Dictionary
	var fusion_snapshot: Dictionary = snapshot.get("perk_fusion", {}) as Dictionary
	return {
		"runtime_skill_levels": (unlock_snapshot.get("runtime_skill_levels", {}) as Dictionary).duplicate(true),
		"physique_training": {
			"acquired_counts": (training_snapshot.get("acquired_counts", {}) as Dictionary).duplicate(true),
			"applied_counts": (training_snapshot.get("applied_counts", {}) as Dictionary).duplicate(true),
			"total_acquired_count": int(training_snapshot.get("total_acquired_count", 0)),
			"eligible_screen_count_before_dice_exhaustion": int(training_snapshot.get("eligible_screen_count_before_dice_exhaustion", 0)),
			"eligible_screen_count_after_dice_exhaustion": int(training_snapshot.get("eligible_screen_count_after_dice_exhaustion", 0)),
		},
		"tower_bag_expansion_count": int(unlock_snapshot.get("tower_bag_expansion_count", 0)),
		"fusion_records": (fusion_snapshot.get("records", []) as Array).duplicate(true),
		"next_fusion_index": int(fusion_snapshot.get("next_fusion_index", 0)),
		"next_fusion_core_stabilize": bool(fusion_snapshot.get("next_fusion_core_stabilize", false)),
		"next_fusion_dual_catalyst": bool(fusion_snapshot.get("next_fusion_dual_catalyst", false)),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
