extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"rest"
)


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var active_item_slots: Array = []
	var runtime_perk_levels: Dictionary = {}
	var special_gauge := 0.0
	var special_gauge_max := 640.0
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
		return instances.get(key, null)


class FakeActiveItemHudState:
	extends RefCounted

	var selected_index := 0

	func get_selected_index() -> int:
		return selected_index

	func set_selected_index(value: int) -> void:
		selected_index = value


class FakeMythicItemRuntime:
	extends RefCounted

	var start_calls := 0
	var refresh_calls := 0

	func start_acquisition_cinematic(
		_item_data: Dictionary,
		_pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		_target_player_center: Vector2 = Vector2.INF
	) -> bool:
		start_calls += 1
		return true

	func refresh_runtime_perk_scaling(
		_owner: Object = null,
		_registry: Object = null
	) -> void:
		refresh_calls += 1


func _initialize() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_campfire_three_choices_lock_and_rest_restore()
	_verify_banana_and_campfire_choices_through_real_flow()
	_verify_banana_atomicity_and_exclusive_catalog()
	_verify_campfire_grant_full_and_success()
	_verify_flag_off_is_untouched()
	LanguageSettings.set_test_locale_override("")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_campfire_n2_seal: choices=3 exact_ko=1 all_three_effects=1 visit_lock=1 gauge_full_once=1 restore=1 banana_gate=1 banana_atomic=1 campfire_full_noop=1 offer_pool=0 locales=7 authority_rng_unchanged=1 result_hold_restore=2 active_inventory=1 selection=1 latest_inventory_export=1 exact_lv1=1 raw_owner_projection=1 failure_external_side_effects=0 snapshot_byte_exact=2")
		print("tower_ascent_rest_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_campfire_three_choices_lock_and_rest_restore() -> void:
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = RuntimePerkState.new()
	registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "campfire-rest",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"registry": registry,
	}), "campfire fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "rest", owner), "campfire fixture must arrive through the real map route")
	var dormant_model: Dictionary = flow.get_node_modal_view_model()
	var before_premature_snapshot := flow.export_persistable_snapshot()
	_expect(_contains_text(dormant_model, "걸음을 가까이 다가가자 모닥불에 불이 타오르기 시작한다") and _contains_text(dormant_model, "평범한 모닥불은 아닌 듯 하다"), "real arrived modal must retain both exact campfire intro lines")
	var premature: Dictionary = flow.execute_node_action("rest:rest", "campfire-rest:premature")
	_expect(not bool(premature.get("accepted", true)) and str(premature.get("reason", "")) == "campfire_sequence_incomplete", "a direct action must not bypass the centered campfire ignition and intro")
	_expect(flow.export_persistable_snapshot() == before_premature_snapshot, "failed campfire action must leave the persistable Tower snapshot byte-identical")
	_click(flow, Vector2(380.0, 318.0))
	for _step in range(6):
		flow.update_selective(0.5, owner)
	var model: Dictionary = flow.get_node_modal_view_model()
	var build_state_before_rest: Dictionary = flow.export_persistable_snapshot().get("build_state", {}).duplicate(true)
	var actions: Array = model.get("actions", [])
	_expect(_find_action(actions, "rest:rest").get("label", "") == "[휴식을 한다]", "campfire rest label must preserve exact Korean copy")
	_expect(_find_action(actions, "rest:cook_banana").get("label", "") == "[바나나 요리를 한다]", "campfire cooking label must preserve exact Korean copy")
	_expect(_find_action(actions, "rest:take_campfire").get("label", "") == "[모닥불을 챙긴다]", "campfire pickup label must preserve exact Korean copy")
	_expect(not bool(_find_action(actions, "rest:cook_banana").get("enabled", true)), "banana-missing cooking must stay visibly disabled in the real modal")
	_expect(str(model.get("campfire_presentation", {}).get("phase", "")) == "menu", "centered campfire click and two retained lines must unlock the three-choice menu")
	var result := flow.execute_node_action("rest:rest", "campfire-rest:pick")
	_expect(bool(result.get("applied", false)) and flow.get_phase_name() == "NODE_MODAL", "one campfire choice must commit into its result presentation")
	var result_model: Dictionary = flow.get_node_modal_view_model()
	_expect(_contains_text(result_model, "좋은 기운으로 전투에 임할 것 같다") and _contains_text(result_model, "다음 전투 진입시 기력이 가득 찬 상태에서 전투를 시작합니다"), "rest result must visibly preserve both exact Korean lines")
	var snapshot := flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "campfire result presentation must be a persistable stable boundary")
	_expect(snapshot.get("build_state", {}) == build_state_before_rest, "pure rest must not rewrite perk or active-inventory build snapshots")
	for _step in range(8):
		flow.update_selective(0.5, owner)
		if flow.get_phase_name() != "NODE_MODAL":
			break
	_expect(flow.get_phase_name() == "ROUTE_AIM", "one campfire result sequence must end at route selection")
	_expect(flow.has_next_battle_full_gauge(), "rest must arm the next-battle full-gauge latch")
	var restored_owner := FakeOwner.new()
	var restored := TowerAscentFlowOwner.new()
	var restored_registry := FakeRegistry.new()
	restored_registry.instances["runtime_perk_state"] = RuntimePerkState.new()
	restored_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), restored_owner, restored_registry), "campfire rest latch must restore")
	_expect(restored.has_next_battle_full_gauge(), "restored campfire latch must remain armed")
	_expect(restored.get_phase_name() == "NODE_MODAL" and _contains_text(restored.get_node_modal_view_model(), "다음 전투 진입시 기력이 가득 찬 상태에서 전투를 시작합니다"), "restored mid-result campfire presentation must retain its canonical result copy")
	_advance_campfire_result_to_route(restored, restored_owner)
	var consumed: Dictionary = restored.consume_next_battle_full_gauge(restored_owner)
	_expect(bool(consumed.get("applied", false)) and is_equal_approx(restored_owner.special_gauge, restored_owner.special_gauge_max), "next battle must consume the latch by filling effective gauge max")
	restored_owner.special_gauge = 17.0
	_expect(not bool(restored.consume_next_battle_full_gauge(restored_owner).get("applied", true)) and is_equal_approx(restored_owner.special_gauge, 17.0), "full-gauge latch must be exactly once")


func _verify_banana_and_campfire_choices_through_real_flow() -> void:
	var banana_owner := FakeOwner.new()
	banana_owner.active_item_slots = [
		{"name": "soap", "fixture_order": 0},
		{"name": "banana", "fixture_order": 1},
	]
	var banana_perk_state := RuntimePerkState.new()
	var banana_registry := FakeRegistry.new()
	var banana_hud_state := FakeActiveItemHudState.new()
	banana_hud_state.selected_index = 0
	banana_registry.instances["runtime_perk_state"] = banana_perk_state
	banana_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	banana_registry.instances["active_item_hud_state"] = banana_hud_state
	var banana_flow := TowerAscentFlowOwner.new()
	_expect(banana_flow.begin_vertical_slice(banana_owner, Callable(), {
		"run_id": "campfire-banana",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"registry": banana_registry,
	}), "banana campfire fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(banana_flow, "rest", banana_owner), "banana campfire fixture must arrive through the real map route")
	var rng_before: Dictionary = banana_flow.export_snapshot().get("gameplay_rng_state", {}).duplicate(true)
	_open_campfire_menu(banana_flow, banana_owner)
	var rng_after: Dictionary = banana_flow.export_snapshot().get("gameplay_rng_state", {}).duplicate(true)
	_expect(rng_after == rng_before, "campfire ignition and retained intro must not advance gameplay RNG")
	var cook_action := _find_action(banana_flow.get_node_modal_view_model().get("actions", []), "rest:cook_banana")
	_expect(bool(cook_action.get("enabled", false)), "owned banana must visibly enable cooking in the real modal")
	var cooked: Dictionary = banana_flow.execute_node_action("rest:cook_banana", "campfire-banana:pick")
	_expect(bool(cooked.get("applied", false)), "banana cooking must commit through the real node action path")
	_expect(banana_owner.active_item_slots.size() == 1 and str(banana_owner.active_item_slots[0].get("name", "")) == "soap" and int(banana_perk_state.runtime_skill_levels.get("banana_master", 0)) == 1, "real banana node choice must consume one banana, preserve unrelated slot order, and grant Banana Master")
	_expect(banana_owner.runtime_perk_levels == banana_perk_state.runtime_skill_levels and int(banana_owner.runtime_perk_levels.get("banana_master", 0)) == 1, "successful Banana Master commit must publish the exact raw owner projection")
	var cooked_model: Dictionary = banana_flow.get_node_modal_view_model()
	var cooked_presentation: Dictionary = banana_flow.get_campfire_presentation_debug_state()
	_expect(str(cooked_presentation.get("phase", "")) == "result" and str(cooked_presentation.get("result_action_id", "")) == "rest:cook_banana", "successful Banana Master commit must start exactly one campfire-owned result presentation")
	_expect(_contains_text(cooked_model, "가방에서 바나나를 꺼내 꼬챙이에 꿰어 불에 달구었다") and _contains_text(cooked_model, "바나나의달인") and _contains_text(cooked_model, "바나나를 던질때 바나나가 2개 발사됩니다"), "banana result presentation must retain all canonical Korean copy")
	_expect((banana_flow.get_rest_history() as Array).size() == 1, "banana cooking must consume exactly one node visit choice")
	var cooked_snapshot := banana_flow.export_persistable_snapshot()
	var restored_banana_owner := FakeOwner.new()
	var restored_banana_perk_state := RuntimePerkState.new()
	var restored_banana_hud_state := FakeActiveItemHudState.new()
	restored_banana_hud_state.selected_index = 2
	var restored_banana_registry := FakeRegistry.new()
	restored_banana_registry.instances["runtime_perk_state"] = restored_banana_perk_state
	restored_banana_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	restored_banana_registry.instances["active_item_hud_state"] = restored_banana_hud_state
	var restored_banana_flow := TowerAscentFlowOwner.new()
	_expect(restored_banana_flow.restore_snapshot(cooked_snapshot, Callable(), restored_banana_owner, restored_banana_registry), "banana result hold must restore through the real persistable Tower snapshot")
	_expect(restored_banana_owner.active_item_slots.size() == 1 and str(restored_banana_owner.active_item_slots[0].get("name", "")) == "soap", "banana result hold restore must preserve unrelated slot order while keeping the banana consumed")
	_expect(int(restored_banana_perk_state.runtime_skill_levels.get("banana_master", 0)) == 1, "banana result hold restore must preserve Banana Master")
	_expect(restored_banana_owner.runtime_perk_levels == restored_banana_perk_state.runtime_skill_levels and int(restored_banana_owner.runtime_perk_levels.get("banana_master", 0)) == 1, "banana result hold restore must republish the exact raw owner projection")
	_expect(restored_banana_hud_state.selected_index == 0, "banana result hold restore must preserve active-item selection")
	_expect((restored_banana_flow.get_rest_history() as Array).size() == 1, "banana result hold restore must preserve exactly one committed history record")
	var replayed_cook: Dictionary = restored_banana_flow.execute_node_action("rest:cook_banana", "campfire-banana:pick")
	_expect(not bool(replayed_cook.get("applied", true)) and restored_banana_owner.active_item_slots.size() == 1 and int(restored_banana_perk_state.runtime_skill_levels.get("banana_master", 0)) == 1, "restored banana resolution must not replay or mutate either committed leg")
	banana_owner.active_item_slots.append({"name": "molotov", "fixture_order": 2})
	banana_hud_state.selected_index = 1
	var later_inventory_snapshot := banana_flow.export_persistable_snapshot()
	var later_owner := FakeOwner.new()
	var later_perk_state := RuntimePerkState.new()
	var later_hud_state := FakeActiveItemHudState.new()
	var later_registry := FakeRegistry.new()
	later_registry.instances["runtime_perk_state"] = later_perk_state
	later_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	later_registry.instances["active_item_hud_state"] = later_hud_state
	var later_flow := TowerAscentFlowOwner.new()
	_expect(later_flow.restore_snapshot(later_inventory_snapshot, Callable(), later_owner, later_registry), "a later stable Tower export must restore after unrelated active-item changes")
	_expect(later_owner.active_item_slots.size() == 2 and str(later_owner.active_item_slots[0].get("name", "")) == "soap" and str(later_owner.active_item_slots[1].get("name", "")) == "molotov", "later stable export must replace the campfire-time image with the latest active inventory order")
	_expect(later_hud_state.selected_index == 1 and int(later_perk_state.runtime_skill_levels.get("banana_master", 0)) == 1, "later stable export must preserve latest selection without losing Banana Master")
	_advance_campfire_result_to_route(banana_flow, banana_owner)

	var pickup_owner := FakeOwner.new()
	pickup_owner.active_item_slots = [{"name": "soap", "fixture_order": 0}]
	var pickup_registry := FakeRegistry.new()
	var pickup_hud_state := FakeActiveItemHudState.new()
	pickup_hud_state.selected_index = 0
	pickup_registry.instances["runtime_perk_state"] = RuntimePerkState.new()
	pickup_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	pickup_registry.instances["active_item_hud_state"] = pickup_hud_state
	var pickup_flow := TowerAscentFlowOwner.new()
	_expect(pickup_flow.begin_vertical_slice(pickup_owner, Callable(), {
		"run_id": "campfire-pickup",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"registry": pickup_registry,
	}), "pickup campfire fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(pickup_flow, "rest", pickup_owner), "pickup campfire fixture must arrive through the real map route")
	_open_campfire_menu(pickup_flow, pickup_owner)
	var picked_up: Dictionary = pickup_flow.execute_node_action("rest:take_campfire", "campfire-pickup:pick")
	_expect(bool(picked_up.get("applied", false)), "campfire pickup must commit through the real node action path")
	_expect(pickup_owner.active_item_slots.size() == 2 and str(pickup_owner.active_item_slots[0].get("name", "")) == "soap" and str(pickup_owner.active_item_slots[1].get("name", "")) == "campfire", "real pickup choice must append exactly one campfire while preserving unrelated slot order")
	_expect((pickup_flow.get_rest_history() as Array).size() == 1, "campfire pickup must consume exactly one node visit choice")
	var committed_pickup_selection := pickup_hud_state.selected_index
	var pickup_snapshot := pickup_flow.export_persistable_snapshot()
	var restored_pickup_owner := FakeOwner.new()
	var restored_pickup_registry := FakeRegistry.new()
	var restored_pickup_hud_state := FakeActiveItemHudState.new()
	restored_pickup_hud_state.selected_index = 2
	restored_pickup_registry.instances["runtime_perk_state"] = RuntimePerkState.new()
	restored_pickup_registry.instances["active_item_runtime"] = ActiveItemRuntime.new()
	restored_pickup_registry.instances["active_item_hud_state"] = restored_pickup_hud_state
	var restored_pickup_flow := TowerAscentFlowOwner.new()
	_expect(restored_pickup_flow.restore_snapshot(pickup_snapshot, Callable(), restored_pickup_owner, restored_pickup_registry), "campfire pickup result hold must restore through the real persistable Tower snapshot")
	_expect(restored_pickup_owner.active_item_slots.size() == 2 and str(restored_pickup_owner.active_item_slots[0].get("name", "")) == "soap" and str(restored_pickup_owner.active_item_slots[1].get("name", "")) == "campfire", "campfire pickup result hold restore must preserve exact inventory order")
	_expect(restored_pickup_hud_state.selected_index == committed_pickup_selection, "campfire pickup restore must preserve the committed active-item selection")
	_expect((restored_pickup_flow.get_rest_history() as Array).size() == 1, "campfire pickup restore must preserve one committed history record")
	var replayed_pickup: Dictionary = restored_pickup_flow.execute_node_action("rest:take_campfire", "campfire-pickup:pick")
	_expect(not bool(replayed_pickup.get("applied", true)) and restored_pickup_owner.active_item_slots.size() == 2, "restored campfire pickup resolution must not replay")
	_advance_campfire_result_to_route(pickup_flow, pickup_owner)


func _verify_banana_atomicity_and_exclusive_catalog() -> void:
	var runtime := ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var perk_state := RuntimePerkState.new()
	var registry := FakeRegistry.new()
	var mythic_runtime := FakeMythicItemRuntime.new()
	var hud_state := FakeActiveItemHudState.new()
	registry.instances["runtime_perk_state"] = perk_state
	registry.instances["mythic_item_runtime"] = mythic_runtime
	registry.instances["active_item_hud_state"] = hud_state
	_expect(not runtime.has_banana(owner), "banana gate must reject an empty inventory")
	_expect(str(runtime.consume_banana_and_grant_mastery(owner, registry).get("reason", "")) == "banana_missing", "banana cooking must recheck inventory at execution")
	owner.active_item_slots = [{"name": "banana"}]
	var inventory_before_failure := runtime.build_tower_inventory_snapshot(owner, registry)
	var perk_before_failure := perk_state.build_tower_reward_mutation_snapshot()
	var rejected: Dictionary = runtime.consume_banana_and_grant_mastery(owner, registry, {"force_grant_rejection": true})
	_expect(not bool(rejected.get("accepted", true)) and bool(rejected.get("precommit_rejection", false)) and owner.active_item_slots.size() == 1 and perk_state.runtime_skill_levels.is_empty(), "injected perk rejection must roll back banana and mastery before the level grant")
	_expect(mythic_runtime.start_calls == 0 and mythic_runtime.refresh_calls == 0, "precommit grant rejection must leave external mythic presentation and consumers untouched")
	_expect(owner.runtime_perk_levels.is_empty(), "precommit grant rejection must not publish a raw owner projection")
	_expect(runtime.build_tower_inventory_snapshot(owner, registry) == inventory_before_failure and perk_state.build_tower_reward_mutation_snapshot() == perk_before_failure, "precommit grant rejection must restore both authoritative snapshots byte-identically")
	var post_failed: Dictionary = runtime.consume_banana_and_grant_mastery(owner, registry, {"force_post_grant_failure": true})
	_expect(not bool(post_failed.get("accepted", true)) and not bool(post_failed.get("precommit_rejection", false)) and bool(post_failed.get("rollback_applied", false)) and owner.active_item_slots.size() == 1 and perk_state.runtime_skill_levels.is_empty(), "postcondition failure after the exact level write must fully roll back both legs")
	_expect(mythic_runtime.start_calls == 0 and mythic_runtime.refresh_calls == 0, "postcondition rejection must leave external mythic presentation and consumers untouched")
	_expect(owner.runtime_perk_levels.is_empty(), "postcondition rejection must not publish a raw owner projection")
	_expect(runtime.build_tower_inventory_snapshot(owner, registry) == inventory_before_failure and perk_state.build_tower_reward_mutation_snapshot() == perk_before_failure, "postcondition rejection must restore both authoritative snapshots byte-identically")
	var success: Dictionary = runtime.consume_banana_and_grant_mastery(owner, registry)
	_expect(bool(success.get("applied", false)) and owner.active_item_slots.is_empty() and int(perk_state.runtime_skill_levels.get("banana_master", 0)) == 1, "banana cooking must consume one banana and grant Banana Master atomically")
	_expect(owner.runtime_perk_levels == perk_state.runtime_skill_levels and int(owner.runtime_perk_levels.get("banana_master", 0)) == 1, "successful exact grant must publish Banana Master to the raw owner projection")
	_expect(mythic_runtime.start_calls == 0 and mythic_runtime.refresh_calls == 1, "successful exact grant must refresh committed mythic consumers once without starting an unroutable bitmap cinematic")
	var catalog := RuntimePerkCatalog.new()
	_expect(not catalog.get_perk_data("banana_master").is_empty(), "Banana Master must resolve by direct acquisition id")
	_expect(not catalog.get_all_perk_data().has("banana_master") and not RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has("banana_master"), "Banana Master must be absent from enumerable general offer pools")
	for character_type in ["smasher", "viper", "soldier", "commando"]:
		_expect(_find_choice(catalog.get_choices(character_type, {}, true, 500), "banana_master").is_empty(), "all general offers must expose zero Banana Master cards for %s" % character_type)


func _verify_campfire_grant_full_and_success() -> void:
	var runtime := ActiveItemRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances["active_item_runtime"] = runtime
	var full_owner := FakeOwner.new()
	full_owner.active_item_slots = [{"name": "banana"}, {"name": "soap"}, {"name": "molotov"}]
	var before := full_owner.active_item_slots.duplicate(true)
	_expect(not runtime.grant_item_to_slot("campfire", full_owner, registry, false) and full_owner.active_item_slots == before, "full active slots must reject campfire without mutation")
	var open_owner := FakeOwner.new()
	_expect(runtime.grant_item_to_slot("campfire", open_owner, registry, false) and open_owner.active_item_slots.size() == 1 and str(open_owner.active_item_slots[0].get("name", "")) == "campfire", "open active slots must grant exactly one campfire")


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "rest-off",
		"node_modal_kind": "rest",
	}), "flag OFF must bypass the rest node")
	_expect(flow.get_rest_history().is_empty(), "flag OFF must not create a rest transaction")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == action_id:
			return raw_action as Dictionary
	return {}


func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return value as Dictionary
	return {}


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


func _click(flow: Object, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	flow.handle_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	flow.handle_input(release)


func _open_campfire_menu(flow: Object, owner: Object) -> void:
	_click(flow, Vector2(380.0, 318.0))
	for _step in range(6):
		flow.update_selective(0.5, owner)
	_expect(str(flow.get_campfire_presentation_debug_state().get("phase", "")) == "menu", "campfire intro sequence must reach its menu phase")


func _advance_campfire_result_to_route(flow: Object, owner: Object) -> void:
	for _step in range(12):
		flow.update_selective(0.5, owner)
		if flow.get_phase_name() != "NODE_MODAL":
			break
	_expect(flow.get_phase_name() == "ROUTE_AIM", "one committed campfire result must end at route selection")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
