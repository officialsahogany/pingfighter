extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const StageClearResultRewardPlanBuilder := preload(
	"res://scripts/core/stage_clear_result_reward_plan_builder.gd"
)
const MatchScoreState := preload(
	"res://scripts/core/match_score_state.gd"
)
const PlazaSaveStore := preload(
	"res://scripts/plaza/plaza_save_store.gd"
)
const RuntimePerkStarpointCollectionFlow := preload(
	"res://scripts/characters/runtime_perk_starpoint_collection_flow.gd"
)
const RuntimePerkStarpointAbsorption := preload(
	"res://scripts/characters/runtime_perk_starpoint_absorption.gd"
)

var _failures: Array[String] = []
var _open_choice_calls := 0


class FakeStarpointState:
	extends RefCounted
	var starpoint_for_skills := 0
	var pending_skill_choices := 0
	var choice_active := false


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_verify_score_scaled_chests_remain_legacy()
	_verify_plaza_gem_store_remains_legacy_owner()
	_verify_starpoint_still_opens_choice_immediately()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_phase_a_off_path_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_score_scaled_chests_remain_legacy() -> void:
	var builder := StageClearResultRewardPlanBuilder.new()
	var observed_counts: Dictionary = {}
	for losing_score in range(0, MatchScoreState.WIN_GOAL):
		var reward_count: int = builder.get_reward_box_count(
			MatchScoreState.WIN_GOAL,
			losing_score
		)
		observed_counts[reward_count] = true
		_expect(
			reward_count != 1,
			"flag OFF regular win must never be folded into the deuce one-box tier"
		)
	_expect(observed_counts.has(3), "flag OFF dominant-win tier must still grant three score-scaled boxes")
	_expect(observed_counts.has(2), "flag OFF regular-win tier must still grant two score-scaled boxes")
	_expect(
		builder.get_reward_box_count(
			MatchScoreState.WIN_GOAL + 1,
			MatchScoreState.DEUCE_TRIGGER
		) == 1,
		"flag OFF deuce win must still grant one score-scaled box"
	)


func _verify_plaza_gem_store_remains_legacy_owner() -> void:
	var save_path := "user://tower_ascent_phase_a_off_%d.cfg" % Time.get_ticks_usec()
	var store := PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.clear()
	store.reset_chance_gems_for_new_playthrough()
	_expect(store.get_chance_gems() == 3, "flag OFF new playthrough must still refill three plaza-owned chance gems")
	_expect(store.consume_chance_gem() == 2, "flag OFF legacy store must consume exactly one chance gem")
	var restored := PlazaSaveStore.new()
	restored.set_save_path(save_path)
	_expect(restored.get_chance_gems() == 2, "flag OFF plaza chance-gem consumption must remain immediately persistent")
	_expect(restored.clear(), "legacy plaza chance-gem fixture must clean up its isolated save")


func _verify_starpoint_still_opens_choice_immediately() -> void:
	var state := FakeStarpointState.new()
	var callbacks := {
		"open_next_choice": Callable(self, "_open_next_choice").bind(state),
	}
	var result: Dictionary = RuntimePerkStarpointCollectionFlow.new().collect_star_points(
		1,
		"smasher",
		null,
		null,
		null,
		false,
		state,
		RuntimePerkStarpointAbsorption.new(),
		null,
		null,
		callbacks,
		1
	)
	_expect(bool(result.get("accepted", false)), "flag OFF starpoint collection must remain accepted")
	_expect(state.choice_active and _open_choice_calls == 1, "flag OFF starpoint collection must still open the perk choice immediately")


func _open_next_choice(
	_character_type: String,
	_catalog: Object,
	_reroll: bool,
	_owner: Object,
	_registry: Object,
	_source: Variant,
	_context: Dictionary,
	state: Object
) -> Dictionary:
	_open_choice_calls += 1
	state.set("choice_active", true)
	return {"accepted": true}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
