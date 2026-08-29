extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageBallSpawnIntroFinishLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_finish_lifecycle.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage: int
	var active_item_slots: Array

	func _init(stage_value: int, slots: Array = []) -> void:
		current_stage = stage_value
		active_item_slots = slots.duplicate(true)


class FakeHudState:
	extends RefCounted

	var selected_index := -1

	func set_selected_index(index: int) -> void:
		selected_index = index


class FakeRoundState:
	extends RefCounted

	var prepared := 0

	func prepare_serve_after_intro() -> void:
		prepared += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeTowerFlow:
	extends RefCounted

	var run_id: String
	var node_id: String

	func _init(run_value: String, node_value: String) -> void:
		run_id = run_value
		node_id = node_value

	func get_run_id() -> String:
		return run_id

	func get_current_node_id() -> String:
		return node_id


class FakeIntro:
	extends RefCounted

	var active := true
	var overlay_active := true
	var serve_handoff_done := false
	var elapsed_sec := 1.0
	var owner_snapshot_calls := 0
	var serve_sync_calls := 0

	func _apply_owner_spawn_snapshot(_owner: Object, _target_pos: Vector2) -> void:
		owner_snapshot_calls += 1

	func _sync_serve_input(_registry: Object) -> void:
		serve_sync_calls += 1

	func _has_completed_serve_handoff() -> bool:
		return serve_handoff_done

	func is_overlay_active() -> bool:
		return active or overlay_active


class FakeIntroReset:
	extends RefCounted

	var calls := 0

	func reset_state(_intro: Object) -> void:
		calls += 1


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_catalog_id_and_korean_name_contracts()
	_verify_catalog_id_mapping_through_production_lifecycle()
	_verify_multi_owned_order_and_actual_inventory_capacity()
	_verify_stage_opportunity_is_first_consumed_and_reset_only()
	_verify_tower_logical_entry_uses_run_and_node_identity()
	_verify_full_inventory_skips_and_never_retries_same_stage()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("runtime_perk_stage_start_item_grant_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_id_and_korean_name_contracts() -> void:
	var perk_catalog := RuntimePerkCatalog.new()
	var item_catalog := ActiveItemCatalog.new()
	for contract: Dictionary in [
		{
			"perk_id": "master",
			"perk_name": "축성공",
			"item_id": "wall",
			"item_name": "토벽패",
		},
		{
			"perk_id": "neural_helmet",
			"perk_name": "강신결",
			"item_id": "aipill",
			"item_name": "신령환",
		},
		{
			"perk_id": "reinforced_boomerang_gauntlet",
			"perk_name": "회선철수",
			"item_id": "boomerang",
			"item_name": "부메랑",
		},
	]:
		var perk_id: String = str(contract["perk_id"])
		var item_id: String = str(contract["item_id"])
		var perk_data: Dictionary = perk_catalog.get_perk_data(perk_id)
		var item_data: Dictionary = item_catalog.build_item_by_name(item_id)
		_expect(str(perk_data.get("id", "")) == perk_id, "%s must be an actual runtime perk catalog id" % perk_id)
		_expect(
			str(perk_data.get("name", "")) == str(contract["perk_name"]),
			"%s must resolve to Korean catalog name %s" % [perk_id, str(contract["perk_name"])]
		)
		_expect(str(item_data.get("name", "")) == item_id, "%s must be an actual active item catalog id" % item_id)
		_expect(
			str(item_data.get("display_name", "")) == str(contract["item_name"]),
			"%s must resolve to Korean catalog name %s" % [item_id, str(contract["item_name"])]
		)


func _verify_catalog_id_mapping_through_production_lifecycle() -> void:
	for mapping: Dictionary in [
		{"perk_id": "master", "item_id": "wall"},
		{"perk_id": "neural_helmet", "item_id": "aipill"},
		{"perk_id": "reinforced_boomerang_gauntlet", "item_id": "boomerang"},
	]:
		var fixture: Dictionary = _build_fixture({str(mapping["perk_id"]): 1})
		_finish_real_intro(fixture)
		var owner: FakeOwner = fixture["owner"]
		var runtime: Object = fixture["runtime"]
		var item_id: String = str(mapping["item_id"])
		_expect(
			_slot_item_ids(owner) == [item_id],
			"%s ownership should grant catalog item id %s through the production intro lifecycle"
			% [str(mapping["perk_id"]), item_id]
		)
		var snapshot: Dictionary = runtime.get_stage_start_item_grant_snapshot()
		var result: Dictionary = snapshot.get("last_result", {})
		_expect(bool(result.get("processed", false)), "production lifecycle should consume the Stage 1 opportunity")
		_expect(result.get("granted_item_ids", []) == [item_id], "facade snapshot should expose the granted catalog id")
		_expect(snapshot.get("processed_stages", []) == [1], "production lifecycle should record exactly Stage 1")
		_expect(int(fixture["round_state"].prepared) == 1, "real intro finish should prepare serve before flushing perks")
		_expect(int(fixture["hud_state"].selected_index) == 0, "actual active item runtime should select the granted slot")


func _verify_multi_owned_order_and_actual_inventory_capacity() -> void:
	var fixture: Dictionary = _build_fixture({
		"master": 1,
		"neural_helmet": 1,
		"reinforced_boomerang_gauntlet": 1,
	})
	var result: Dictionary = _call_facade(fixture)
	var expected_ids := ["wall", "aipill", "boomerang"]
	_expect(result.get("granted_item_ids", []) == expected_ids, "multiple owned mugong should grant in stable mapping order")
	_expect(_slot_item_ids(fixture["owner"]) == expected_ids, "actual active item runtime should fill the three base slots in mapping order")
	_expect((result.get("skipped_grants", []) as Array).is_empty(), "three mapped grants should fit the three-slot base inventory")


func _verify_stage_opportunity_is_first_consumed_and_reset_only() -> void:
	var fixture: Dictionary = _build_fixture({})
	var runtime: Object = fixture["runtime"]
	var owner: FakeOwner = fixture["owner"]

	var unowned: Dictionary = _call_facade(fixture)
	_expect(bool(unowned.get("processed", false)), "a valid unowned stage should still consume its one opportunity")
	_expect(str(unowned.get("reason", "")) == "no_owned_mugong", "unowned entry should report no_owned_mugong")
	_expect(str(unowned.get("entry_kind", "")) == "stage", "non-Tower entry should use the current-stage fallback")
	_expect(str(unowned.get("entry_key", "")) == "stage:1", "normal Stage 1 should expose the current-stage dedupe key")
	_expect(owner.active_item_slots.is_empty(), "unowned entry should not grant an item")

	runtime.runtime_skill_levels["master"] = 1
	var same_stage: Dictionary = _call_facade(fixture)
	_expect(str(same_stage.get("reason", "")) == "already_processed", "acquiring a mugong later must not retry the same stage")
	_expect(owner.active_item_slots.is_empty(), "same-stage retry must remain item-free")

	owner.current_stage = 2
	var next_stage: Dictionary = _call_facade(fixture)
	_expect(next_stage.get("granted_item_ids", []) == ["wall"], "the next stage should own a fresh grant opportunity")
	_expect(_slot_item_ids(owner) == ["wall"], "next-stage grant should reach the actual inventory")

	runtime.reset()
	runtime.runtime_skill_levels["master"] = 1
	owner.current_stage = 1
	var after_reset: Dictionary = _call_facade(fixture)
	_expect(after_reset.get("granted_item_ids", []) == ["wall"], "full runtime reset should clear the stage ledger")
	_expect(_slot_item_ids(owner) == ["wall", "wall"], "reset ledger clear should allow a new-run Stage 1 grant")
	_expect(
		runtime.get_stage_start_item_grant_snapshot().get("processed_stages", []) == [1],
		"reset should clear old stage history before the new Stage 1 entry"
	)


func _verify_tower_logical_entry_uses_run_and_node_identity() -> void:
	var fixture: Dictionary = _build_fixture({"master": 1}, 1)
	var owner: FakeOwner = fixture["owner"]
	var registry: FakeRegistry = fixture["registry"]
	var flow := FakeTowerFlow.new("tower-entry-run", "floor01-combat-a")
	registry.instances["tower_ascent_flow_owner"] = flow

	var first: Dictionary = _call_facade(fixture)
	_expect(first.get("granted_item_ids", []) == ["wall"], "first Tower node entry should grant its mapped item")
	_expect(str(first.get("entry_kind", "")) == "tower", "valid Tower owner identity should select the Tower entry lane")
	_expect(str(first.get("run_id", "")) == flow.run_id, "Tower entry result should retain the authoritative run id")
	_expect(str(first.get("node_id", "")) == flow.node_id, "Tower entry result should retain the authoritative current node id")

	var same_node_retry: Dictionary = _call_facade(fixture)
	_expect(str(same_node_retry.get("reason", "")) == "already_processed", "same Tower node retry must be deduplicated")
	_expect(owner.active_item_slots.size() == 1, "same Tower node retry must not grant a duplicate item")

	flow.node_id = "floor02-combat-b"
	var different_node_same_stage: Dictionary = _call_facade(fixture)
	_expect(owner.current_stage == 1, "Tower regression fixture must keep the same legacy current_stage value")
	_expect(
		different_node_same_stage.get("granted_item_ids", []) == ["wall"],
		"a different Tower node in the same current_stage must receive its own grant"
	)
	_expect(owner.active_item_slots.size() == 2, "two distinct Tower nodes should produce exactly two granted items")
	_expect(
		str(different_node_same_stage.get("node_id", "")) == "floor02-combat-b",
		"second Tower result should expose the new authoritative node id"
	)
	var snapshot: Dictionary = fixture["runtime"].get_stage_start_item_grant_snapshot()
	var entry_keys: Array = snapshot.get("processed_entry_keys", [])
	_expect(entry_keys.size() == 2, "Tower ledger should contain one key per distinct run-and-node entry")
	_expect(snapshot.get("processed_stages", []) == [1], "Tower nodes may share one legacy stage without collapsing their entry keys")


func _verify_full_inventory_skips_and_never_retries_same_stage() -> void:
	var full_slots: Array = [
		{"name": "gauge_charge", "effect": "gauge_charge"},
		{"name": "life_elixir", "effect": "life_elixir"},
		{"name": "wall", "effect": "wall"},
	]
	var fixture: Dictionary = _build_fixture({"master": 1}, 1, full_slots)
	var owner: FakeOwner = fixture["owner"]
	var rejected: Dictionary = _call_facade(fixture)
	var skipped: Array = rejected.get("skipped_grants", [])

	_expect(str(rejected.get("reason", "")) == "grant_rejected", "full inventory should report a rejected grant")
	_expect(owner.active_item_slots.size() == 3, "full inventory must remain unchanged when overflow is false")
	_expect(skipped.size() == 1, "full inventory should expose one skipped mapping")
	if skipped.size() == 1 and skipped[0] is Dictionary:
		var skip: Dictionary = skipped[0]
		_expect(str(skip.get("perk_id", "")) == "master", "skip result should retain the owning mugong id")
		_expect(str(skip.get("item_id", "")) == "wall", "skip result should retain the rejected item id")
		_expect(
			str(skip.get("reason", "")) == "inventory_full_or_grant_rejected",
			"skip result should expose the inventory rejection reason"
		)

	owner.active_item_slots.pop_back()
	var same_stage: Dictionary = _call_facade(fixture)
	_expect(str(same_stage.get("reason", "")) == "already_processed", "making room must not reopen the consumed stage opportunity")
	_expect(owner.active_item_slots.size() == 2, "same-stage retry must not fill the newly opened slot")


func _build_fixture(levels: Dictionary, stage: int = 1, slots: Array = []) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	runtime.runtime_skill_levels = levels.duplicate(true)
	var active_item_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new(stage, slots)
	var hud_state := FakeHudState.new()
	var round_state := FakeRoundState.new()
	var registry := FakeRegistry.new({})
	registry.instances = {
		"runtime_perk_state": runtime,
		"active_item_runtime": active_item_runtime,
		"active_item_hud_state": hud_state,
		"round_flow_state": round_state,
	}
	return {
		"runtime": runtime,
		"active_item_runtime": active_item_runtime,
		"owner": owner,
		"registry": registry,
		"hud_state": hud_state,
		"round_state": round_state,
	}


func _finish_real_intro(fixture: Dictionary) -> void:
	var intro := FakeIntro.new()
	var intro_reset := FakeIntroReset.new()
	StageBallSpawnIntroFinishLifecycle.new().finish_intro(
		intro,
		fixture["owner"],
		fixture["registry"],
		Vector2(200.0, 300.0),
		intro_reset
	)
	_expect(not intro.active and not intro.overlay_active, "real intro finish should close the overlay")
	_expect(intro.owner_snapshot_calls == 1, "real intro finish should apply the spawn snapshot")
	_expect(intro.serve_sync_calls == 1, "real intro finish should synchronize serve input")
	_expect(intro_reset.calls == 1, "real intro finish should run reset lifecycle")


func _call_facade(fixture: Dictionary) -> Dictionary:
	var runtime: Object = fixture["runtime"]
	var result: Dictionary = runtime.on_ball_spawn_intro_finished(
		fixture["owner"],
		fixture["registry"]
	)
	var stage_result: Variant = result.get("stage_start_item_grant", {})
	return stage_result if stage_result is Dictionary else {}


func _slot_item_ids(owner: FakeOwner) -> Array[String]:
	var ids: Array[String] = []
	for slot_value: Variant in owner.active_item_slots:
		if slot_value is Dictionary:
			ids.append(str((slot_value as Dictionary).get("name", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
