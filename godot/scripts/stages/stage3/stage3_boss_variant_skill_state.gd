extends "res://scripts/stages/stage3/stage3_boss_skill_state.gd"

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")

var teddy_bear_state: Object = TeddyBearBossState.new()
var active_variant := "yeonmyo"


func reset() -> void:
	super.reset()
	if teddy_bear_state != null:
		teddy_bear_state.reset()


func reset_round() -> void:
	if active_variant == "teddy_bear":
		teddy_bear_state.reset_round()
	else:
		super.reset_round()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	active_variant = StageBossVariantCatalog.normalize_variant(3, context.get("stage_boss_variant", ""))
	if active_variant == "teddy_bear":
		return teddy_bear_state.update(delta, context, deps)
	return super.update(delta, context, deps)


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	active_variant = StageBossVariantCatalog.normalize_variant(3, context.get("stage_boss_variant", ""))
	if active_variant == "teddy_bear":
		return teddy_bear_state.register_boss_hit(ball_vel, context, deps)
	return super.register_boss_hit(ball_vel, context, deps)


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if active_variant == "teddy_bear":
		teddy_bear_state.handle_score_event(scoring_side, score_result, deps)
	else:
		super.handle_score_event(scoring_side, score_result, deps)


func get_hud_context(stage_background: Object = null, context: Dictionary = {}) -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_hud_context(stage_background, context)
	return super.get_hud_context(stage_background, context)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_actor_draw_context(copy_arrays)
	return super.get_actor_draw_context(copy_arrays)


func get_boss_gauge_progress() -> float:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_boss_gauge_progress()
	return super.get_boss_gauge_progress()


func is_curse_reverse_active() -> bool:
	return false if active_variant == "teddy_bear" else super.is_curse_reverse_active()


func is_psychoball_hitstop_active() -> bool:
	return false if active_variant == "teddy_bear" else super.is_psychoball_hitstop_active()


func is_kuromi_awakening_active() -> bool:
	return false if active_variant == "teddy_bear" else super.is_kuromi_awakening_active()


func is_kuromi_ball_hidden() -> bool:
	return false if active_variant == "teddy_bear" else super.is_kuromi_ball_hidden()


func force_kuromi_awake() -> void:
	if active_variant != "teddy_bear":
		super.force_kuromi_awake()


func is_deadly_hug_dash_blocked() -> bool:
	return active_variant == "teddy_bear" and teddy_bear_state.is_deadly_hug_dash_blocked()


func get_snapshot() -> Dictionary:
	if active_variant == "teddy_bear":
		return teddy_bear_state.get_snapshot()
	return super.get_snapshot()
