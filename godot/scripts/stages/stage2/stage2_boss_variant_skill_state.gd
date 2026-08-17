extends "res://scripts/stages/stage2/stage2_boss_skill_state.gd"

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")

var molewang_state: Object = MolewangBossState.new()
var active_variant := "cheongringwi"


func reset() -> void:
	super.reset()
	if molewang_state != null:
		molewang_state.reset()


func reset_round() -> void:
	if active_variant == "molewang":
		molewang_state.reset_round()
	else:
		super.reset_round()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	active_variant = StageBossVariantCatalog.normalize_variant(2, context.get("stage_boss_variant", ""))
	if active_variant == "molewang":
		return molewang_state.update(delta, context, deps)
	return super.update(delta, context, deps)


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	active_variant = StageBossVariantCatalog.normalize_variant(2, context.get("stage_boss_variant", ""))
	if active_variant == "molewang":
		return molewang_state.register_boss_hit(ball_vel, context, deps)
	return super.register_boss_hit(ball_vel, context, deps)


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if active_variant == "molewang":
		molewang_state.handle_score_event(scoring_side, score_result, deps)


func get_boss_ai_context(stage_background: Object = null) -> Dictionary:
	return molewang_state.get_boss_ai_context(stage_background) if active_variant == "molewang" else super.get_boss_ai_context(stage_background)


func get_hud_context(stage_background: Object = null, context: Dictionary = {}) -> Dictionary:
	return molewang_state.get_hud_context(stage_background, context) if active_variant == "molewang" else super.get_hud_context(stage_background, context)


func get_pressure_snapshot(context: Dictionary = {}) -> Dictionary:
	return molewang_state.get_pressure_snapshot(context) if active_variant == "molewang" else super.get_pressure_snapshot(context)


func get_actor_draw_context() -> Dictionary:
	return molewang_state.get_actor_draw_context() if active_variant == "molewang" else super.get_actor_draw_context()


func get_status() -> String:
	return molewang_state.get_status() if active_variant == "molewang" else super.get_status()


func is_speed_defense_active() -> bool:
	return molewang_state.is_speed_defense_active() if active_variant == "molewang" else super.is_speed_defense_active()


func is_boss_status_immune() -> bool:
	return molewang_state.is_boss_status_immune() if active_variant == "molewang" else super.is_boss_status_immune()


func get_quake_cooldown() -> float:
	return molewang_state.get_quake_cooldown() if active_variant == "molewang" else super.get_quake_cooldown()


func get_boss_special_gauge() -> float:
	return molewang_state.get_boss_special_gauge() if active_variant == "molewang" else super.get_boss_special_gauge()


func get_boss_gauge_max() -> float:
	return molewang_state.get_boss_gauge_max() if active_variant == "molewang" else super.get_boss_gauge_max()


func get_boss_gauge_progress() -> float:
	return molewang_state.get_boss_gauge_progress() if active_variant == "molewang" else super.get_boss_gauge_progress()


func get_water_cannon_delay() -> float:
	return molewang_state.get_water_cannon_delay() if active_variant == "molewang" else super.get_water_cannon_delay()


func get_water_cannon_delay_total() -> float:
	return molewang_state.get_water_cannon_delay_total() if active_variant == "molewang" else super.get_water_cannon_delay_total()


func defer_water_cannon_after_rock_spawn(delay_sec: float = WATER_CANNON_AFTER_ROCK_SPAWN_GRACE_SEC) -> void:
	if active_variant == "molewang":
		molewang_state.defer_water_cannon_after_rock_spawn(delay_sec)
	else:
		super.defer_water_cannon_after_rock_spawn(delay_sec)
