extends SceneTree

const BattleSceneMatchFlowDriver := preload(
	"res://scripts/core/battle_scene_match_flow_driver.gd"
)
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerRewardPickState := preload(
	"res://scripts/tower_ascent/tower_reward_pick_state.gd"
)
const VictoryLootPhaseState := preload(
	"res://scripts/core/victory_loot_phase_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const PICKUP_MUHON := 6
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)
const RECORD_STORE_PATH := "user://tower_victory_margin_muhon_reward_smoke.json"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var chance_gems_count := 0
	var chance_gems_max := 3
	var victory_loot_phase_active := false


class MutableScoreboard:
	extends RefCounted

	var player_points := 7
	var boss_points := 3
	var win_goal := 7
	var last_scoring_side := "player"

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func get_last_scoring_side() -> String:
		return last_scoring_side


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}

	func capture_stats_context(owner: Object, registry: Object) -> bool:
		return owner != null and registry != null

	func get_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"pending_skill_choices": 0,
			"gold_from_perks": 0,
			"current_choices": [],
			"particles": [],
			"physique_training": {},
		}

	func get_physique_training_snapshot() -> Dictionary:
		return {}

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass


class FakeCatalog:
	extends RefCounted

	func get_perk_slot_status(runtime_levels: Dictionary, _slot_context: Object = null) -> Dictionary:
		return {
			"count": runtime_levels.size(),
			"limit": 6,
			"is_full": runtime_levels.size() >= 6,
		}


class FakeCardRenderer:
	extends RefCounted

	func prewarm_traditional_choice_assets() -> void:
		pass


class FakeIconRenderer:
	extends RefCounted

	func prewarm_assets() -> void:
		pass


class FixedOfferBuilder:
	extends RefCounted

	func build_offer(
		_context: Dictionary,
		_owner: Object,
		_registry: Object,
		_roll_overrides: Dictionary = {}
	) -> Dictionary:
		var choices: Array[Dictionary] = []
		for index in range(4):
			choices.append({
				"id": "margin_reward_card_%d" % index,
				"name": "보상 카드 %d" % (index + 1),
				"description": "점수차 무혼 생산 경로 씰",
				"reward_pick_kind": "mugong",
				"reward_pick_cost": 99,
				"reward_pick_price_text": "무혼 99",
			})
		return {"accepted": true, "choices": choices}


class ImmediateContinueScreen:
	extends RefCounted

	var show_calls := 0

	func show_with_consume(
		_owner: Object,
		_registry: Object,
		continue_callback: Callable,
		consume_callback: Callable
	) -> bool:
		show_calls += 1
		if consume_callback.is_valid():
			consume_callback.call()
		if continue_callback.is_valid():
			continue_callback.call()
		return true


class LegacyPlanBuilder:
	extends RefCounted

	func build_reward_plan(_player_score: int, _boss_score: int) -> Dictionary:
		return {"boxes": []}


class CountingFlowOwner:
	extends RefCounted

	var margin_reward_calls := 0

	func apply_victory_margin_reward(_player_score: int, _boss_score: int) -> Dictionary:
		margin_reward_calls += 1
		return {"accepted": true, "applied": true}


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	LanguageSettings.set_test_locale_override("ko")
	_verify_score_margin_cases()
	_verify_exact_once_reentry_snapshot_and_display()
	_verify_defeat_retry_path()
	_verify_non_tower_reverse_leg()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")
	_cleanup_record_store()
	if _failures.is_empty():
		print("tower_victory_margin_muhon_reward_smoke: PASS=9 FAIL=0 TOTAL=9")
		print("tower_victory_margin_muhon_reward_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("tower_victory_margin_muhon_reward_smoke: PASS=0 FAIL=%d TOTAL=9" % _failures.size())
	quit(1)


func _verify_score_margin_cases() -> void:
	var cases := [
		{"player": 7, "boss": 3, "win_goal": 7, "expected": 4, "label": "7:3"},
		{"player": 7, "boss": 0, "win_goal": 7, "expected": 7, "label": "7:0"},
		{"player": 10, "boss": 9, "win_goal": 7, "expected": 1, "label": "10:9 deuce"},
		# GRT-054 counter-fixture: the formula must survive a changed winning rule.
		{"player": 11, "boss": 8, "win_goal": 11, "expected": 3, "label": "11:8 variable win goal"},
	]
	for score_case in cases:
		var fixture := _build_victory_fixture(
			int(score_case.player),
			int(score_case.boss),
			int(score_case.win_goal),
			PICKUP_MUHON,
			0,
			"margin-case-%s" % str(score_case.label).replace(":", "-")
		)
		_dispatch_scoreboard_reset(fixture)
		var expected_balance := PICKUP_MUHON + int(score_case.expected)
		_expect(
			int((fixture.flow as Object).get_run_state_snapshot().get("muhon", -1)) == expected_balance,
			"%s production settlement must award measured margin %d" % [score_case.label, score_case.expected]
		)
		_expect(
			(fixture.flow as Object).get_victory_margin_reward_history().size() == 1,
			"%s must journal exactly one victory-margin transaction" % score_case.label
		)
		_expect(
			(fixture.loot as Object).is_reward_pick_active(),
			"%s must reach the production reward-pick screen" % score_case.label
		)
		(fixture.loot as Object).reset()


func _verify_exact_once_reentry_snapshot_and_display() -> void:
	var fixture := _build_victory_fixture(7, 3, 7, PICKUP_MUHON, 0, "margin-exact-once")
	_dispatch_scoreboard_reset(fixture)
	var first_balance := int((fixture.flow as Object).get_run_state_snapshot().get("muhon", -1))
	_expect(first_balance == PICKUP_MUHON + 4, "first settlement must add pickup income and +4 margin")
	(fixture.loot as Object).reset()
	_dispatch_scoreboard_reset(fixture)
	_expect(
		int((fixture.flow as Object).get_run_state_snapshot().get("muhon", -1)) == first_balance,
		"same combat settlement reentry must not duplicate the margin reward"
	)
	_expect(
		(fixture.flow as Object).get_victory_margin_reward_history().size() == 1,
		"same combat settlement reentry must retain one transaction record"
	)
	var reward_state: Object = (fixture.loot as Object).get("_reward_pick_state")
	var model: Dictionary = reward_state.build_view_model(LIVE_VIEW_SIZE)
	_expect(str(model.get("balance_text", "")) == "무혼 : 10개", "reward-pick opening balance must include pickup income plus margin")
	_expect(str(model.get("acquisition_text", "")) == "무혼 +4 (점수차 보상)", "reward-pick header must show one Korean acquisition line without an em dash")
	var renderer := RuntimePerkOverlayRenderer.new()
	var layout: Dictionary = model.get("layout", {})
	var title_pos: Vector2 = layout.get("title_pos", Vector2.ZERO)
	var balance_rows := renderer.build_tower_reward_balance_rows(
		LIVE_VIEW_SIZE,
		title_pos,
		minf(float(layout.get("layout_scale", 1.0)), 1.0),
		str(model.get("balance_text", ""))
	)
	var acquisition_rows := renderer.build_tower_reward_acquisition_rows(
		LIVE_VIEW_SIZE,
		balance_rows,
		str(model.get("acquisition_text", ""))
	)
	_expect(balance_rows.size() == 1 and acquisition_rows.size() == 1, "live reward header must fit one balance row and one acquisition row")
	if acquisition_rows.size() == 1:
		_expect(
			Rect2(Vector2.ZERO, LIVE_VIEW_SIZE).encloses((acquisition_rows[0] as Dictionary).get("rect", Rect2())),
			"victory-margin acquisition row must stay inside the live viewport"
		)
	reward_state.call("_finish")
	var flow: Object = fixture.flow
	_expect(flow.get_phase_name() == "ROUTE_AIM", "reward-pick continue must commit combat and begin route serving")
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	_expect(not targets.is_empty(), "snapshot leg needs a production route target")
	if targets.is_empty():
		return
	flow.debug_launch_at_target(0)
	for _frame in range(240):
		flow.update_selective(1.0 / 60.0, fixture.owner)
		if flow.get_phase_name() != "ROUTE_AIM":
			break
	_expect(
		flow.get_phase_name() == "MAP_TRANSITION",
		"snapshot leg must reach the post-selection stable boundary, got %s" % flow.get_phase_name()
	)
	var snapshot: Dictionary = flow.export_snapshot()
	_expect(bool(snapshot.get("stable_boundary", false)), "post-selection snapshot must be stable")
	_expect((snapshot.get("victory_margin_reward_history", []) as Array).size() == 1, "snapshot must serialize the margin transaction journal")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "snapshot carrying the margin journal must restore")
	_expect(
		int(restored.get_run_state_snapshot().get("muhon", -1)) == first_balance,
		"snapshot restore must preserve the awarded balance without replaying the reward"
	)
	_expect(restored.get_victory_margin_reward_history().size() == 1, "snapshot restore must preserve one margin resolution id")
	# Break the active flow -> registry -> flow fixture cycle before SceneTree exit.
	flow.call("_reset_runtime_state")
	restored.call("_reset_runtime_state")


func _verify_defeat_retry_path() -> void:
	var fixture := _build_victory_fixture(3, 7, 7, PICKUP_MUHON, 1, "margin-defeat-retry")
	var continue_screen := ImmediateContinueScreen.new()
	(fixture.registry as FakeRegistry).instances["defeat_chance_gems_continue_screen"] = continue_screen
	(fixture.flow as Object).set_record_store_path_for_tests(RECORD_STORE_PATH)
	(fixture.scoreboard as MutableScoreboard).last_scoring_side = "boss"
	_dispatch_scoreboard_reset(fixture)
	_expect(continue_screen.show_calls == 1, "tower defeat must enter the chance-gem retry path")
	_expect(
		int((fixture.flow as Object).get_run_state_snapshot().get("muhon", -1)) == PICKUP_MUHON,
		"defeat before retry must award zero margin Muhon"
	)
	_expect((fixture.flow as Object).get_victory_margin_reward_history().is_empty(), "defeat must not create a margin transaction")
	(fixture.scoreboard as MutableScoreboard).player_points = 7
	(fixture.scoreboard as MutableScoreboard).boss_points = 3
	(fixture.scoreboard as MutableScoreboard).last_scoring_side = "player"
	_dispatch_scoreboard_reset(fixture)
	_expect(
		int((fixture.flow as Object).get_run_state_snapshot().get("muhon", -1)) == PICKUP_MUHON + 4,
		"victory after retry must award the measured margin exactly once"
	)
	_expect((fixture.flow as Object).get_victory_margin_reward_history().size() == 1, "retry victory must create one margin transaction")
	(fixture.loot as Object).reset()


func _verify_non_tower_reverse_leg() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := CountingFlowOwner.new()
	var registry := FakeRegistry.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	var loot := VictoryLootPhaseState.new()
	loot.set("_plan_builder", LegacyPlanBuilder.new())
	_expect(
		not loot.start(FakeOwner.new(), registry, 7, 3, Callable()),
		"flag-OFF campaign victory must retain the legacy empty-plan result fallback"
	)
	_expect(not loot.is_reward_pick_active(), "flag-OFF campaign victory must not open the Tower reward pick")
	_expect(flow.margin_reward_calls == 0, "flag-OFF campaign victory must not touch the Tower margin economy")
	loot.reset()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _build_victory_fixture(
	player_score: int,
	boss_score: int,
	win_goal: int,
	initial_muhon: int,
	chance_gems: int,
	run_id: String
) -> Dictionary:
	var owner := FakeOwner.new()
	var scoreboard := MutableScoreboard.new()
	scoreboard.player_points = player_score
	scoreboard.boss_points = boss_score
	scoreboard.win_goal = win_goal
	scoreboard.last_scoring_side = "player" if player_score > boss_score else "boss"
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.ensure_run_started(owner, {
		"run_id": run_id,
		"run_state": {
			"muhon": initial_muhon,
			"gold": 0,
			"chance_gems": chance_gems,
		},
	}), "%s fixture must start the run-local economy" % run_id)
	var reward_state := TowerRewardPickState.new()
	reward_state.set("_offer_builder", FixedOfferBuilder.new())
	var loot := VictoryLootPhaseState.new()
	loot.set("_reward_pick_state", reward_state)
	var registry := FakeRegistry.new()
	registry.instances = {
		"scoreboard_state": scoreboard,
		"tower_ascent_flow_owner": flow,
		"victory_loot_phase_state": loot,
		"runtime_perk_state": FakeRuntimeState.new(),
		"runtime_perk_catalog": FakeCatalog.new(),
		"runtime_perk_overlay_renderer": FakeCardRenderer.new(),
		"runtime_perk_icon_renderer": FakeIconRenderer.new(),
	}
	return {
		"driver": BattleSceneMatchFlowDriver.new(),
		"owner": owner,
		"scoreboard": scoreboard,
		"flow": flow,
		"loot": loot,
		"registry": registry,
	}


func _dispatch_scoreboard_reset(fixture: Dictionary) -> void:
	(fixture.driver as Object).apply_scoreboard_update_result(
		ScoreboardState.UPDATE_RESET_GAME,
		fixture.registry,
		fixture.owner,
		Callable(),
		Callable()
	)


func _cleanup_record_store() -> void:
	var absolute_path := ProjectSettings.globalize_path(RECORD_STORE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
