extends SceneTree

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentSettlementState := preload(
	"res://scripts/tower_ascent/tower_ascent_settlement_state.gd"
)
const TowerAscentSettlementLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_settlement_localization.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _exit_calls := 0


class FakeScoreboard:
	extends RefCounted
	func get_player_points() -> int:
		return 0
	func get_boss_points() -> int:
		return MatchScoreState.WIN_GOAL
	func get_win_goal() -> int:
		return MatchScoreState.WIN_GOAL
	func get_last_scoring_side() -> String:
		return "boss"


class FakeRuntimeState:
	extends RefCounted
	var pause_calls := 0
	var resume_calls := 0
	var arm_calls := 0
	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass
	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1
	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1
	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		arm_calls += 1


class TrapLegacySettlement:
	extends RefCounted
	var show_calls := 0
	func show(_owner: Object, _registry: Object, _callback: Callable) -> bool:
		show_calls += 1
		return true


class FakeRegistry:
	extends RefCounted
	var scoreboard := FakeScoreboard.new()
	var runtime := FakeRuntimeState.new()
	var legacy_settlement := TrapLegacySettlement.new()
	func get_instance(key: String) -> Object:
		if key == "scoreboard_state":
			return scoreboard
		if key == "runtime_perk_state":
			return runtime
		if key == "defeat_settlement_screen":
			return legacy_settlement
		return null
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeOwner:
	extends RefCounted
	var current_stage := 6
	var chance_gems_count := 0
	var chance_gems_max := 0
	var redraws := 0
	func request_battle_redraw() -> void:
		redraws += 1


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var save_path := "user://tower_ascent_run_settlement_%d.cfg" % Time.get_ticks_usec()
	_cleanup(save_path)
	_verify_summary_assembly_contract()
	_verify_currency_summary_locales()
	_verify_zero_gem_defeat_routes_to_shared_settlement(save_path)
	_cleanup(save_path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_run_settlement_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_currency_summary_locales() -> void:
	var expected := {
		LanguageSettings.LANGUAGE_KOREAN: "무혼 17 · 금화 91",
		LanguageSettings.LANGUAGE_ENGLISH: "Muhon 17 · Gold 91",
		LanguageSettings.LANGUAGE_CHINESE: "武魂 17 · 金币 91",
		LanguageSettings.LANGUAGE_JAPANESE: "武魂 17 · 金貨 91",
		LanguageSettings.LANGUAGE_SPANISH: "Muhon 17 · Oro 91",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Muhon 17 · Ouro 91",
		LanguageSettings.LANGUAGE_RUSSIAN: "Мухон 17 · Золото 91",
	}
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var summary := TowerAscentSettlementState.build_lost_build_summary(
			{"muhon": 17, "gold": 91}, {}, {}
		)
		var rows: Array = summary.get("rows", [])
		_expect(rows.size() == 1, "%s settlement fixture must append one currency row" % locale)
		if rows.size() == 1:
			_expect(str(rows[0]) == str(expected.get(locale, "")), "%s settlement currency row must use its locale block" % locale)
		var locale_text: Dictionary = TowerAscentSettlementLocalization.TEXT_BY_LOCALE.get(locale, {})
		_expect(locale_text.has(TowerAscentSettlementLocalization.KEY_LOST_BUILD_CURRENCY_ROW), "%s settlement catalog must register the currency row" % locale)
	LanguageSettings.set_test_locale_override("")


func _verify_summary_assembly_contract() -> void:
	var lost_build := TowerAscentSettlementState.build_lost_build_summary(
		{"muhon": 17, "gold": 91},
		{
			"mugong": [{"id": "mugong_a"}],
			"chosik": [{"id": "chosik_a"}, {"id": "chosik_b"}],
			"active_items": [{"id": "active_a"}],
			"mythic": {"mythic_a": 2},
		},
		{
			"active_guardian": {"pet_id": "baekrin"},
			"sealed_guardians": [{"pet_id": "mokrin"}],
		}
	)
	_expect(int(lost_build.get("mugong_count", 0)) == 1, "lost build should summarize mugong")
	_expect(int(lost_build.get("chosik_count", 0)) == 2, "lost build should summarize chosik")
	_expect(int(lost_build.get("active_item_count", 0)) == 1, "lost build should summarize active items")
	_expect((lost_build.get("rows", []) as Array).has("수호령 1종"), "settlement must count only the active guardian after sealed-roster retirement")
	var sealed_only := TowerAscentSettlementState.build_lost_build_summary(
		{},
		{},
		{"sealed_guardians": [{"pet_id": "mokrin"}]}
	)
	_expect(not (sealed_only.get("rows", []) as Array).any(func(row: Variant) -> bool: return str(row).begins_with("수호령 ")), "legacy sealed guardians must not contribute to settlement counts")
	var income := TowerAscentSettlementState.build_persistent_income(
		{"highest_floor": 9, "clear_count": 2},
		[{"pet_id": "baekrin", "display_name": "백린", "discovery_id": "first:baekrin"}]
	)
	var state := TowerAscentSettlementState.new()
	var result: Dictionary = state.open("defeat", "settlement:assembly", 9, lost_build, income)
	_expect(bool(result.get("accepted", false)), "settlement fixture should open")
	var snapshot: Dictionary = state.export_state()
	_expect(snapshot.get("assembly_order", []) == ["lost_build", "persistent_income"], "lost build must be assembled above persistent income")
	var view_model: Dictionary = state.build_view_model()
	_expect((view_model.get("lost_build_rows", []) as Array).size() >= 5, "lost build rows should retain all run-only categories")
	_expect((view_model.get("persistent_income_rows", []) as Array).size() == 3, "persistent income should show discovery and record updates")
	_expect(not view_model.has("unlock_currency"), "unresolved unlock currency must not create a settlement slot")


func _verify_zero_gem_defeat_routes_to_shared_settlement(save_path: String) -> void:
	_exit_calls = 0
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	_expect(flow.prepare_vertical_slice_combat(owner, {
		"run_id": "settlement-defeat",
		"current_stage": owner.current_stage,
		"map_seed": 4606,
		"run_state": {"chance_gems": 0},
		"registry": registry,
	}), "defeat fixture should prepare a generated run")
	_expect(flow.begin_vertical_slice(owner, Callable(), {"registry": registry}), "defeat fixture should enter the generated flow")
	_expect(flow.resolve_defeat(registry, owner, Callable(), Callable(self, "_record_exit")), "zero-gem defeat should be handled")
	_expect(flow.get_phase_name() == "RUN_SETTLEMENT", "zero-gem defeat should open the tower shared settlement")
	_expect(registry.legacy_settlement.show_calls == 0, "tower settlement must not fall through to the legacy defeat settlement")
	_expect(int(flow.get_record_snapshot().get("highest_floor", 0)) == owner.current_stage, "defeat should persist the reached floor immediately")
	var model: Dictionary = flow.get_settlement_view_model()
	_expect(str(model.get("result_kind", "")) == "defeat", "defeat settlement should use the defeat variant")
	_expect(not model.has("unlock_currency"), "defeat variant must not invent unlock currency")
	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "open settlement should be a crash-safe snapshot boundary")
	var restore_owner := FakeOwner.new()
	var restore_registry := FakeRegistry.new()
	flow = null
	var restored := TowerAscentFlowOwner.new()
	restored.set_record_store_path_for_tests(save_path)
	_expect(restored.restore_snapshot(snapshot, Callable(self, "_record_exit"), restore_owner, restore_registry), "defeat settlement should restore after a crash")
	_expect(restored.get_phase_name() == "RUN_SETTLEMENT", "restored settlement should remain open")
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	_expect(restored.handle_input(confirm), "settlement should consume confirm")
	_expect(_exit_calls == 1 and not restored.is_active(), "settlement should invoke the exit callback once")
	_expect(restore_registry.runtime.resume_calls == 1 and restore_registry.runtime.arm_calls == 1, "settlement close should restore modal lifecycle once")


func _record_exit() -> void:
	_exit_calls += 1


func _cleanup(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
