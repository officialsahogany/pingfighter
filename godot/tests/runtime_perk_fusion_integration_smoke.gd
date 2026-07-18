extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUpdateDriver := preload("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

var _failures: Array[String] = []


class RegistryStub:
	extends RefCounted

	var runtime_state: Object
	var runtime_catalog: Object


	func _init(state_value: Object, catalog_value: Object) -> void:
		runtime_state = state_value
		runtime_catalog = catalog_value


	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_state
			"runtime_perk_catalog":
				return runtime_catalog
		return null


func _init() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}

	_expect(catalog.count_owned_slot_perks(state.runtime_skill_levels, registry) == 2, "two unfused unit-slot perks should occupy two slots")
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "success"},
		catalog
	)
	_expect(not record.is_empty(), "runtime facade should commit a valid fusion")
	_expect(catalog.count_owned_slot_perks(state.runtime_skill_levels, registry) == 1, "one fusion record should refund exactly one occupied slot")
	_expect(state.get_perk_fusion_slot_reduction() == 1, "runtime facade should expose the slot reduction")

	var snapshot: Dictionary = state.get_snapshot()
	_expect(int(snapshot.get("fusion_revision", 0)) == state.get_perk_fusion_revision(), "runtime snapshot should expose fusion revision")
	var display_projection: Dictionary = snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	_expect(int(display_projection.get("fusion_revision", 0)) == state.get_perk_fusion_revision(), "runtime snapshot should expose the canonical fusion display revision")
	var fusion_snapshot: Dictionary = snapshot.get("perk_fusion", {}) as Dictionary
	_expect((fusion_snapshot.get("records", []) as Array).size() == 1, "runtime snapshot should carry the fusion record")
	var restored_state := RuntimePerkState.new()
	restored_state.runtime_skill_levels = state.runtime_skill_levels.duplicate(true)
	restored_state.restore_perk_fusion_snapshot(fusion_snapshot, catalog)
	var restored_projection: Dictionary = restored_state.get_perk_fusion_display_projection()
	_expect((restored_projection.get("entries", []) as Array).size() == 1, "restored run snapshot should retain the catalog needed to fold both fusion sources")
	(fusion_snapshot.get("records", []) as Array).clear()
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).size() == 1, "runtime snapshot should deep-copy fusion state")

	var reverb_state := RuntimePerkState.new()
	reverb_state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	var reverb_record: Dictionary = reverb_state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["reverb"]},
		catalog
	)
	_expect(not reverb_record.is_empty(), "reverb lifecycle fixture should commit")
	reverb_state.notify_perk_fusion_skill_used()
	_expect(
		is_equal_approx(reverb_state.get_perk_fusion_move_speed_multiplier(), 1.25),
		"reverb should activate before the gameplay driver tick"
	)
	_expect(
		is_equal_approx(reverb_state.get_player_speed_multiplier(), 1.25),
		"the REAL player-speed stat composition must consume the active reverb buff"
	)
	RuntimePerkUpdateDriver.new().update_runtime_perk_resume(
		null,
		RegistryStub.new(reverb_state, catalog),
		3.01
	)
	_expect(
		is_equal_approx(reverb_state.get_perk_fusion_move_speed_multiplier(), 1.0),
		"the always-on gameplay update driver should expire reverb without an overlay"
	)
	_expect(
		is_equal_approx(reverb_state.get_player_speed_multiplier(), 1.0),
		"the real player-speed stat must return to 1.0 after reverb expires"
	)

	_verify_full_slots_refund_reaches_all_consumers()

	state.reset()
	_expect(state.runtime_skill_levels.is_empty(), "new-run reset should clear runtime perk levels")
	_expect((state.get_perk_fusion_snapshot().get("records", []) as Array).is_empty(), "new-run reset should clear fusion records")
	_expect(state.get_perk_fusion_slot_reduction() == 0, "new-run reset should clear fusion slot reduction")

	if _failures.is_empty():
		print("runtime_perk_fusion_integration_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


# 코덱스 보강 #2: 슬롯 환급을 '전' 소비자가 봐야 한다 — 6/6에서 융합
# 1건이면 일반 슬롯퍽 오퍼(실 get_choices 필터), 신화 강제 지급 판정,
# TAB/ESC 양쪽 UI 슬롯 표기가 모두 5/6을 읽는다. 소비자별 자체 계산이
# 하나라도 남으면 이 레그가 RED가 된다.
func _verify_full_slots_refund_reaches_all_consumers() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	catalog.mythic_jackpot_offer_chance = 0.0
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"dash_lightweight": 5,
		"dash_module_control": 5,
		"dash_jump": 1,
		"common_swiftness": 1,
	}
	var full_status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, registry)
	_expect(int(full_status.get("count", -1)) == 6 and int(full_status.get("limit", 0)) == 6, "six unit slot perks should read 6/6 before fusion")
	_expect(not catalog.has_open_perk_slot(state.runtime_skill_levels, registry), "6/6 should report no open slot")
	var full_offer_ids: Array = _collect_unowned_slot_perk_offer_ids(catalog, state, registry)
	_expect(full_offer_ids.is_empty(), "the real 6/6 offer path must not offer any new slot-consuming perk (saw: %s)" % str(full_offer_ids))
	var mythic_full: Dictionary = MythicPerkGrantHelper.build_reward(null, registry)
	_expect(str(mythic_full.get("type", "")) == "starpoint", "the real mythic grant path must fall back to starpoints at 6/6")

	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "success"},
		catalog
	)
	_expect(not record.is_empty(), "slot consumer fixture should commit one fusion")
	var open_status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, registry)
	_expect(int(open_status.get("count", -1)) == 5 and int(open_status.get("limit", 0)) == 6, "one fusion should refund the shared status to 5/6 through the registry context")
	var state_context_status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, state)
	_expect(int(state_context_status.get("count", -1)) == 5, "the runtime-state slot context (ESC overlay flavor) should read the same 5/6 refund")
	_expect(catalog.has_open_perk_slot(state.runtime_skill_levels, registry), "5/6 should report an open slot")
	var open_offer_ids: Array = _collect_unowned_slot_perk_offer_ids(catalog, state, registry)
	_expect(not open_offer_ids.is_empty(), "the real 5/6 offer path should resume offering new slot-consuming perks")
	var mythic_open: Dictionary = MythicPerkGrantHelper.build_reward(null, registry)
	_expect(str(mythic_open.get("type", "")) == "mythic_perk", "the real mythic grant path should grant a mythic perk once the fusion refund opens a slot")

	var tab_body: String = _extract_function_body("res://scripts/hud/character_info_overlay_core.gd", "func _draw_perk_grid(")
	_expect(tab_body.contains("catalog.get_perk_slot_status(levels, registry)"), "the TAB perk grid must read slot status through the registry slot context")
	var esc_body: String = _extract_function_body("res://scripts/hud/runtime_perk_overlay_renderer.gd", "func _draw_status_panel(")
	_expect(esc_body.contains("get_perk_slot_status(levels, runtime_state)"), "the ESC status panel must read slot status through the runtime-state slot context")
	PerkConversionFlags.debug_set_enabled(false)


# 실 오퍼 경로 판정: 고정 시드 10개로 get_choices를 돌려 '미보유 슬롯 소비
# 퍽' 오퍼 id의 합집합을 모은다 — 6/6 부재 판정은 필터가 시드와 무관하게
# 보장하고, 5/6 존재 판정은 고정 시드라 결정적이다.
func _collect_unowned_slot_perk_offer_ids(catalog: Object, state: Object, registry: Object) -> Array:
	var found: Array = []
	for seed_index: int in range(10):
		seed(41000 + seed_index)
		var choices: Array = catalog.get_choices("smasher", state.runtime_skill_levels, true, 4, null, registry)
		for choice_value: Variant in choices:
			if not (choice_value is Dictionary):
				continue
			var choice_id := str((choice_value as Dictionary).get("id", ""))
			if choice_id.is_empty() or int(state.runtime_skill_levels.get(choice_id, 0)) > 0:
				continue
			var data: Dictionary = catalog.get_perk_data(choice_id)
			if data.is_empty():
				continue
			data["id"] = choice_id
			if RuntimePerkCatalog.is_slot_consuming_perk(data) and not found.has(choice_id):
				found.append(choice_id)
	return found


func _extract_function_body(script_path: String, signature_prefix: String) -> String:
	var source: String = FileAccess.get_file_as_string(script_path)
	var start: int = source.find(signature_prefix)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature_prefix.length())
	var next_static: int = source.find("\nstatic func ", start + signature_prefix.length())
	var end: int = next_func
	if next_static >= 0 and (end < 0 or next_static < end):
		end = next_static
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
