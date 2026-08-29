extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveLevels := preload(
	"res://scripts/characters/runtime_perk_effective_levels.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowEconomyProgress := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)

const TREASURE_MAP_ID := "downtown_treasure_map"

var _failures: Array[String] = []


class FakeRuntimeState:
	extends RefCounted

	const EffectiveLevels := preload(
		"res://scripts/characters/runtime_perk_effective_levels.gd"
	)

	var runtime_skill_levels: Dictionary = {}
	var current_choice_context: Dictionary = {}
	var fusion_active := false
	var fusion_cost_query_calls := 0

	func get_downtown_treasure_map_fusion_muhon_cost(base_cost: int) -> int:
		fusion_cost_query_calls += 1
		return EffectiveLevels.new().get_downtown_treasure_map_fusion_muhon_cost(
			runtime_skill_levels,
			0,
			false,
			base_cost
		)

	func build_unlock_save_snapshot() -> Dictionary:
		return {"runtime_skill_levels": runtime_skill_levels.duplicate(true)}

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		var choice_id := str(choice.get("id", "")).strip_edges()
		if choice_id.is_empty():
			return false
		runtime_skill_levels[choice_id] = int(runtime_skill_levels.get(choice_id, 0)) + 1
		return true

	func begin_tower_reward_fusion_modal(_choice: Dictionary, _registry: Object) -> bool:
		fusion_active = true
		return true

	func is_perk_fusion_modal_active() -> bool:
		return fusion_active

	func apply_tower_reward_mugong_replacement(
		_target_token: Dictionary,
		_new_choice: Dictionary,
		_owner: Object,
		_registry: Object,
		_catalog: Object = null
	) -> Dictionary:
		return {"accepted": true, "applied": true}


class FakeFlowOwner:
	extends RefCounted

	var muhon := 0
	var last_purchase_cost := -1
	var last_offer_generation := -1

	func get_reward_pick_context() -> Dictionary:
		return {"node_resolution_id": "treasure-map-cost-fixture"}

	func get_run_state_snapshot() -> Dictionary:
		return {"muhon": muhon, "gold": 0, "chance_gems": 0}

	func apply_reward_pick_purchase(
		_slot_index: int,
		_choice: Dictionary,
		cost: int,
		effect_callback: Callable,
		_rollback_callback: Callable = Callable(),
		offer_generation: int = 0
	) -> Dictionary:
		last_purchase_cost = cost
		last_offer_generation = offer_generation
		if muhon < cost:
			return {"accepted": false, "applied": false, "reason": "insufficient_muhon"}
		if not bool(effect_callback.call()):
			return {"accepted": false, "applied": false, "reason": "effect_rejected"}
		muhon -= cost
		return {"accepted": true, "applied": true, "reason": "applied"}


class FakeRefreshOfferBuilder:
	extends RefCounted

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {},
		offer_generation: int = 0
	) -> Dictionary:
		return {
			"accepted": true,
			"offer_generation": offer_generation,
			"choices": [{
				"id": "refresh_replacement_card",
				"name": "새 보상",
				"reward_pick_kind": "mugong",
				"reward_pick_cost": 1,
			}],
		}


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_progression_and_runtime_facade()
	_verify_live_reward_pick_payment_path()
	_verify_non_fusion_route_exclusions()
	_verify_production_flow_debit_history()
	_verify_catalog_and_seven_locale_copy()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("treasure_map_fusion_cost_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_progression_and_runtime_facade() -> void:
	var helper := RuntimePerkEffectiveLevels.new()
	var cases := [
		{"level": 0, "base": 3, "expected": 3},
		{"level": 1, "base": 3, "expected": 2},
		{"level": 2, "base": 3, "expected": 0},
		{"level": 3, "base": 3, "expected": 0},
		{"level": 2, "base": 1, "expected": 0},
		{"level": 3, "base": 9, "expected": 0},
		{"level": 3, "base": -4, "expected": 0},
	]
	for case: Dictionary in cases:
		var level := int(case.get("level", 0))
		var base_cost := int(case.get("base", 0))
		var expected := int(case.get("expected", 0))
		var levels := {TREASURE_MAP_ID: level} if level > 0 else {}
		_expect_eq(
			helper.get_downtown_treasure_map_fusion_muhon_cost(
				levels,
				0,
				false,
				base_cost
			),
			expected,
			"pure cost owner Lv.%d base %d" % [level, base_cost]
		)
	_expect_eq(
		helper.get_downtown_treasure_map_fusion_muhon_cost(
			{TREASURE_MAP_ID: 1},
			1,
			false,
			7
		),
		4,
		"owned Lv.1 plus one effective-level bonus must use the Lv.2 reduction"
	)
	_expect_eq(
		helper.get_downtown_treasure_map_fusion_muhon_cost(
			{TREASURE_MAP_ID: 1},
			0,
			true,
			7
		),
		0,
		"owned Lv.1 plus Ignition Aura must reach the fixed-free milestone"
	)

	var runtime := RuntimePerkState.new()
	runtime.runtime_skill_levels = {TREASURE_MAP_ID: 1, "item_polish": 3}
	_expect_eq(
		runtime.get_downtown_treasure_map_fusion_muhon_cost(3),
		2,
		"public runtime facade must not Polish-amplify the structural cost tier"
	)
	runtime.runtime_skill_levels[TREASURE_MAP_ID] = 3
	_expect_eq(
		runtime.get_downtown_treasure_map_fusion_muhon_cost(50),
		0,
		"max rank must stay fixed free when the base cost increases"
	)


func _verify_live_reward_pick_payment_path() -> void:
	for case: Dictionary in [
		{"level": 0, "base": 3, "balance": 3, "cost": 3},
		{"level": 1, "base": 3, "balance": 2, "cost": 2},
		{"level": 2, "base": 3, "balance": 0, "cost": 0},
		{"level": 3, "base": 3, "balance": 0, "cost": 0},
		{"level": 2, "base": 1, "balance": 0, "cost": 0},
		{"level": 3, "base": 9, "balance": 0, "cost": 0},
	]:
		var fixture := _fusion_fixture(
			int(case.get("level", 0)),
			int(case.get("base", 0)),
			int(case.get("balance", 0))
		)
		_assert_view_and_purchase(
			fixture,
			int(case.get("cost", 0)),
			"Lv.%d base %d" % [int(case.get("level", 0)), int(case.get("base", 0))]
		)

	_verify_same_screen_treasure_map_purchase()


func _verify_same_screen_treasure_map_purchase() -> void:
	var runtime := FakeRuntimeState.new()
	var flow := FakeFlowOwner.new()
	flow.muhon = 2
	var state := TowerRewardPickState.new()
	state.active = true
	state.choices = [
		{
			"id": TREASURE_MAP_ID,
			"name": "천기보도",
			"reward_pick_kind": "mugong",
			"reward_pick_cost": 0,
		},
		{
			"id": "perk_fusion",
			"name": "무공 합일",
			"reward_pick_kind": "fusion",
			"reward_pick_cost": 3,
		},
	]
	state.spent_flags = [false, false]
	state.set("_runtime_state", runtime)
	state.set("_flow_owner", flow)
	var before_choices: Array = state.build_view_model().get("choices", [])
	var before_fusion: Dictionary = before_choices[1] if before_choices.size() > 1 else {}
	_expect_eq(int(before_fusion.get("reward_pick_cost", -1)), 3, "same-screen unowned fusion cost")
	_expect(not bool(before_fusion.get("reward_pick_enabled", true)), "same-screen base cost must be unaffordable at 2 Muhon")

	state.call("_purchase", 0)
	_expect_eq(int(runtime.runtime_skill_levels.get(TREASURE_MAP_ID, 0)), 1, "first purchase must really grant Treasure Map Lv.1")
	_expect_eq(flow.muhon, 2, "free Treasure Map fixture must preserve Muhon before Fusion")
	var after_choices: Array = state.build_view_model().get("choices", [])
	var after_fusion: Dictionary = after_choices[1] if after_choices.size() > 1 else {}
	_expect_eq(int(after_fusion.get("reward_pick_cost", -1)), 2, "same-screen purchased Treasure Map fusion cost")
	_expect(bool(after_fusion.get("reward_pick_enabled", false)), "same-screen Treasure Map purchase must enable Fusion at 2 Muhon")
	_expect(
		str(after_fusion.get("reward_pick_price_text", ""))
		== TowerRewardPickLocalization.text("price", {"amount": 2}),
		"same-screen price text must refresh after the real Treasure Map purchase"
	)
	state.call("_purchase", 1)
	_expect_eq(flow.last_purchase_cost, 2, "same-screen refreshed transaction cost")
	_expect_eq(flow.muhon, 0, "same-screen refreshed real Muhon debit")
	_expect(bool((state.get("spent_flags") as Array)[1]), "same-screen Fusion must commit after the Treasure Map purchase")


func _verify_non_fusion_route_exclusions() -> void:
	var refresh_runtime := FakeRuntimeState.new()
	refresh_runtime.runtime_skill_levels[TREASURE_MAP_ID] = 3
	var refresh_flow := FakeFlowOwner.new()
	refresh_flow.muhon = 4
	var refresh_state := TowerRewardPickState.new()
	refresh_state.active = true
	refresh_state.choices = [{
		"id": "reward_refresh",
		"name": "새로고침",
		"reward_pick_kind": "refresh",
		"reward_pick_cost": 4,
	}]
	refresh_state.spent_flags = [false]
	refresh_state.set("_runtime_state", refresh_runtime)
	refresh_state.set("_flow_owner", refresh_flow)
	refresh_state.set("_offer_builder", FakeRefreshOfferBuilder.new())
	var refresh_choices: Array = refresh_state.build_view_model().get("choices", [])
	var refresh_card: Dictionary = refresh_choices[0] if not refresh_choices.is_empty() else {}
	_expect_eq(int(refresh_card.get("reward_pick_cost", -1)), 4, "refresh card must retain its base cost")
	_expect_eq(refresh_runtime.fusion_cost_query_calls, 0, "refresh view must not query the Treasure Map Fusion discount")
	refresh_state.call("_purchase", 0)
	_expect_eq(refresh_flow.last_purchase_cost, 4, "refresh transaction must retain its base cost")
	_expect_eq(refresh_flow.muhon, 0, "refresh transaction must debit its undiscounted cost")
	_expect_eq(refresh_flow.last_offer_generation, 0, "refresh transaction must carry its v3 offer generation")
	_expect_eq(refresh_runtime.fusion_cost_query_calls, 0, "refresh purchase must not query the Treasure Map Fusion discount")

	var replacement_runtime := FakeRuntimeState.new()
	replacement_runtime.runtime_skill_levels[TREASURE_MAP_ID] = 3
	var replacement_flow := FakeFlowOwner.new()
	replacement_flow.muhon = 5
	var replacement_choice := {
		"id": "peerless_replacement_fixture",
		"name": "교체 무공",
		"reward_pick_kind": "supreme",
		"reward_pick_cost": 5,
		"reward_pick_replacement_eligible": true,
	}
	var replacement_state := TowerRewardPickState.new()
	replacement_state.active = true
	replacement_state.choices = [replacement_choice]
	replacement_state.spent_flags = [false]
	replacement_state.set("_runtime_state", replacement_runtime)
	replacement_state.set("_flow_owner", replacement_flow)
	var replacement_choices: Array = replacement_state.build_view_model().get("choices", [])
	var replacement_card: Dictionary = (
		replacement_choices[0] if not replacement_choices.is_empty() else {}
	)
	_expect_eq(int(replacement_card.get("reward_pick_cost", -1)), 5, "replacement candidate must retain its base cost")
	_expect_eq(replacement_runtime.fusion_cost_query_calls, 0, "replacement view must not query the Treasure Map Fusion discount")
	replacement_state.set("_replacement_slot_index", 0)
	replacement_state.set("_replacement_choice", replacement_choice.duplicate(true))
	replacement_state._replacement_candidates.append({
		"target_token": {
			"target_kind": "perk",
			"target_id": "existing_mugong",
			"slot_cell_index": 0,
		},
	})
	replacement_state.set("_replacement_selected_index", 0)
	replacement_state.call("_confirm_mugong_replacement")
	_expect_eq(replacement_flow.last_purchase_cost, 5, "replacement transaction must retain its base cost")
	_expect_eq(replacement_flow.muhon, 0, "replacement transaction must debit its undiscounted cost")
	_expect(bool((replacement_state.get("spent_flags") as Array)[0]), "replacement transaction must commit once")
	_expect_eq(replacement_runtime.fusion_cost_query_calls, 0, "replacement purchase must not query the Treasure Map Fusion discount")


func _verify_production_flow_debit_history() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowEconomyProgress.new()
	flow.set("_prepared", true)
	flow.set("_prepared_resolution_id", "feedback12-treasure-map")
	flow.set("_current_node_id", "floor_01_reward")
	var run_state := flow.get("_run_state") as Object
	_expect(
		run_state != null and run_state.begin("feedback12-cost-run", {"muhon": 2}),
		"production run-state fixture must start with two Muhon"
	)

	var runtime := FakeRuntimeState.new()
	runtime.runtime_skill_levels[TREASURE_MAP_ID] = 1
	var state := TowerRewardPickState.new()
	state.active = true
	state.choices = [{
		"id": "perk_fusion",
		"name": "무공 합일",
		"reward_pick_kind": "fusion",
		"reward_pick_cost": 3,
	}]
	state.spent_flags = [false]
	state.set("_runtime_state", runtime)
	state.set("_flow_owner", flow)
	state.call("_purchase", 0)

	var balances: Dictionary = run_state.export_economy() if run_state != null else {}
	var history: Array[Dictionary] = flow.get_reward_pick_history()
	var record: Dictionary = history[0] if history.size() == 1 else {}
	_expect_eq(int(balances.get("muhon", -1)), 0, "production RunState must debit the resolved Lv.1 cost")
	_expect(history.size() == 1, "production flow must record exactly one reward-pick transaction")
	_expect_eq(int(record.get("cost", -1)), 2, "production flow history must record the resolved cost")
	_expect(str(record.get("choice_kind", "")) == "fusion", "production flow history must retain the Fusion kind")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _assert_view_and_purchase(fixture: Dictionary, expected_cost: int, label: String) -> void:
	var state := fixture.get("state") as Object
	var flow := fixture.get("flow") as FakeFlowOwner
	var before := flow.muhon
	var model: Dictionary = state.build_view_model()
	var model_choices: Array = model.get("choices", [])
	var choice: Dictionary = model_choices[0] if not model_choices.is_empty() else {}
	_expect_eq(
		int(choice.get("reward_pick_cost", -1)),
		expected_cost,
		"%s view cost" % label
	)
	_expect(
		str(choice.get("reward_pick_price_text", ""))
		== TowerRewardPickLocalization.text("price", {"amount": expected_cost}),
		"%s localized price must follow the live cost" % label
	)
	_expect(bool(choice.get("reward_pick_enabled", false)), "%s affordability must use the live cost" % label)
	state.call("_purchase", 0)
	_expect_eq(flow.last_purchase_cost, expected_cost, "%s transaction cost" % label)
	_expect_eq(flow.muhon, before - expected_cost, "%s real Muhon debit" % label)
	_expect(bool((state.get("spent_flags") as Array)[0]), "%s purchase must commit once" % label)


func _fusion_fixture(level: int, base_cost: int, balance: int) -> Dictionary:
	var runtime := FakeRuntimeState.new()
	if level > 0:
		runtime.runtime_skill_levels[TREASURE_MAP_ID] = level
	var flow := FakeFlowOwner.new()
	flow.muhon = balance
	var state := TowerRewardPickState.new()
	state.active = true
	state.choices = [{
		"id": "perk_fusion",
		"name": "무공 합일",
		"reward_pick_kind": "fusion",
		"reward_pick_cost": base_cost,
		"reward_pick_price_text": TowerRewardPickLocalization.text(
			"price",
			{"amount": base_cost}
		),
	}]
	state.spent_flags = [false]
	state.set("_runtime_state", runtime)
	state.set("_flow_owner", flow)
	return {"state": state, "runtime": runtime, "flow": flow}


func _verify_catalog_and_seven_locale_copy() -> void:
	var treasure_map: Dictionary = RuntimePerkCatalog.new().get_perk_data(TREASURE_MAP_ID)
	var descriptions: Dictionary = treasure_map.get("descriptions", {})
	_expect(str(descriptions.get(1, "")).contains("무공 합일 무혼 비용 -1"), "Korean Lv.1 copy must show -1")
	_expect(str(descriptions.get(2, "")).contains("무공 합일 무혼 비용 -3"), "Korean Lv.2 copy must show -3")
	_expect(str(descriptions.get(3, "")).contains("무공 합일 무혼 비용 없음"), "Korean max-rank copy must show free")
	_expect(str(treasure_map.get("detail", "")).contains("0으로 고정"), "Korean detail must explain fixed-zero max rank")

	var localized := {
		"en": [LanguageSettingsData.PERK_SUMMARY_EN, "1 less", "3 less", "is free"],
		"zh": [LanguageSettingsData.PERK_SUMMARY_ZH, "减少1点", "减少3点", "免费"],
		"ja": [LanguageSettingsData.PERK_SUMMARY_JA, "Lv.1で1", "Lv.2で3", "無料"],
		"es": [LanguageSettingsData.PERK_SUMMARY_ES, "1 alma marcial menos", "3 menos", "gratis"],
		"pt-BR": [LanguageSettingsData.PERK_SUMMARY_PT_BR, "1 alma marcial a menos", "3 a menos", "grátis"],
		"ru": [LanguageSettingsData.PERK_SUMMARY_RU, "на 1 боевую душу меньше", "на 3 меньше", "бесплат"],
	}
	for locale_value: Variant in localized.keys():
		var locale := str(locale_value)
		var fixture: Array = localized[locale]
		var summaries: Dictionary = fixture[0]
		var summary := str(summaries.get("treasure_map", ""))
		_expect(
			summary.contains("150%")
			and summary.contains(str(fixture[1]))
			and summary.contains(str(fixture[2]))
			and summary.contains(str(fixture[3])),
			"%s summary must describe -1, -3, and fixed-free max rank" % locale
		)
		_expect(not summary.contains("—"), "%s summary must not use an em dash" % locale)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	_expect(actual == expected, "%s: got %d expected %d" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
