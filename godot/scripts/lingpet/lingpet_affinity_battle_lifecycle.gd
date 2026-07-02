extends RefCounted

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")

var _last_bond_settlement: Dictionary = {}


func reset_all() -> void:
	_last_bond_settlement = {}


func get_last_bond_settlement() -> Dictionary:
	return _last_bond_settlement.duplicate(true)


func handle_score_event(
	scoring_side: String,
	score_result: Dictionary,
	registry: Object,
	affinity_pet_id: String,
	affinity_state: Object,
	grant_affinity_points: Callable
) -> void:
	var normalized_pet_id := affinity_pet_id.strip_edges().to_lower()
	var match_finished := bool(score_result.get("match_finished", false))
	if normalized_pet_id != "" and grant_affinity_points.is_valid():
		# 2026-06-12 design decision: only PLAYER-scored commits pay the +5
		# round reward. A lost point paying affinity read as wrong once the
		# +N popup made the income visible.
		if scoring_side == "player":
			grant_affinity_points.call(normalized_pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
		if scoring_side == "player" and match_finished:
			grant_affinity_points.call(normalized_pet_id, LingpetAffinityState.SOURCE_VICTORY, {}, registry)
			# A player-won match finish IS the stage clear (one boss per stage), so pay the
			# +50 stage-clear bonus on top of the +20 victory at the same eligible moment.
			grant_affinity_points.call(normalized_pet_id, LingpetAffinityState.SOURCE_STAGE_CLEAR, {}, registry)
	if match_finished:
		if scoring_side == "player":
			_settle_bond_level_ups(affinity_state)
		else:
			_discard_pending_bond_level_ups(affinity_state)


func reset_for_new_battle(income_tracker: Object, affinity_state: Object) -> void:
	if income_tracker != null and income_tracker.has_method("flush_battle_log"):
		income_tracker.flush_battle_log("battle_reset")
	if affinity_state != null and affinity_state.has_method("reset_for_new_battle"):
		affinity_state.reset_for_new_battle()
	_last_bond_settlement = {}


func _settle_bond_level_ups(affinity_state: Object) -> void:
	# v5 / per-run: bond settlement is still recorded for the victory result /
	# feedback, but no longer persisted to the store.
	if affinity_state == null or not affinity_state.has_method("settle_bond_level_ups_for_victory"):
		_last_bond_settlement = {}
		return
	_last_bond_settlement = affinity_state.settle_bond_level_ups_for_victory()


func _discard_pending_bond_level_ups(affinity_state: Object) -> void:
	if affinity_state == null or not affinity_state.has_method("discard_pending_bond_level_ups"):
		_last_bond_settlement = {}
		return
	_last_bond_settlement = affinity_state.discard_pending_bond_level_ups()
