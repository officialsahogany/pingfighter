extends "res://scripts/stages/stage3/stage3_boss_skill_state.gd"

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")
const AliceBossState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")

var teddy_bear_state: Object = TeddyBearBossState.new()
var alice_state: Object = AliceBossState.new()
var active_variant := "yeonmyo"


func reset() -> void:
	super.reset()
	if teddy_bear_state != null:
		teddy_bear_state.reset()
	if alice_state != null:
		alice_state.reset()


func reset_round(deps: Dictionary = {}) -> void:
	if active_variant == "teddy_bear":
		teddy_bear_state.reset_round()
	elif active_variant == "alice":
		alice_state.reset_round(deps)
	else:
		super.reset_round()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _select_explicit_variant(context):
		return {}
	if active_variant == "teddy_bear":
		return teddy_bear_state.update(delta, context, deps)
	if active_variant == "alice":
		return alice_state.update(delta, context, deps)
	return super.update(delta, context, deps)


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _select_explicit_variant(context):
		return {}
	if active_variant == "teddy_bear":
		return teddy_bear_state.register_boss_hit(ball_vel, context, deps)
	if active_variant == "alice":
		return alice_state.register_boss_hit(ball_vel, context, deps)
	return super.register_boss_hit(ball_vel, context, deps)


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if active_variant == "teddy_bear":
		teddy_bear_state.handle_score_event(scoring_side, score_result, deps)
	elif active_variant == "alice":
		alice_state.handle_score_event(scoring_side, score_result, deps)
	else:
		super.handle_score_event(scoring_side, score_result, deps)


func get_hud_context(stage_background: Object = null, context: Dictionary = {}) -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_hud_context(stage_background, context)
	if active_variant == "alice":
		return alice_state.get_hud_context(stage_background, context)
	return super.get_hud_context(stage_background, context)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_actor_draw_context(copy_arrays)
	if active_variant == "alice":
		return alice_state.get_actor_draw_context(copy_arrays)
	return super.get_actor_draw_context(copy_arrays)


func get_boss_gauge_progress() -> float:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_boss_gauge_progress()
	if active_variant == "alice":
		return alice_state.get_boss_gauge_progress()
	return super.get_boss_gauge_progress()


func is_curse_reverse_active() -> bool:
	return false if active_variant in ["teddy_bear", "alice"] else super.is_curse_reverse_active()


func is_psychoball_hitstop_active() -> bool:
	return false if active_variant in ["teddy_bear", "alice"] else super.is_psychoball_hitstop_active()


func is_kuromi_awakening_active() -> bool:
	return false if active_variant in ["teddy_bear", "alice"] else super.is_kuromi_awakening_active()


func is_kuromi_ball_hidden() -> bool:
	return false if active_variant in ["teddy_bear", "alice"] else super.is_kuromi_ball_hidden()


func force_kuromi_awake() -> void:
	if active_variant not in ["teddy_bear", "alice"]:
		super.force_kuromi_awake()


func is_deadly_hug_dash_blocked() -> bool:
	return active_variant == "teddy_bear" and teddy_bear_state.is_deadly_hug_dash_blocked()


func get_snapshot() -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_snapshot()
	if active_variant == "alice":
		return alice_state.get_snapshot()
	return super.get_snapshot()


func _select_explicit_variant(context: Dictionary) -> bool:
	# An ABSENT key means the caller lost the variant context, so fail closed
	# rather than routing a variant boss into the default boss logic. A key that
	# is PRESENT but empty is the legitimate campaign state: entering at stage 1
	# normalizes to "" and no non-tower transition ever rewrites the owner field,
	# so "" must still resolve to this stage's default boss.
	if not context.has("stage_boss_variant"):
		return false
	var requested: Variant = context.get("stage_boss_variant", "")
	if str(requested).strip_edges().is_empty():
		active_variant = StageBossVariantCatalog.get_default_variant(3)
		return true
	if not StageBossVariantCatalog.is_ported_variant(3, requested):
		return false
	active_variant = StageBossVariantCatalog.normalize_variant(3, requested)
	return true
