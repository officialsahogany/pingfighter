extends "res://scripts/stages/stage2/stage2_boss_skill_state.gd"

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")

var molewang_state: Object = MolewangBossState.new()
var arachne_state: Object = ArachneBossState.new()
var active_variant := "cheongringwi"


func reset() -> void:
	super.reset()
	if molewang_state != null:
		molewang_state.reset()
	if arachne_state != null:
		arachne_state.reset()


func reset_round() -> void:
	if active_variant == "molewang":
		molewang_state.reset_round()
	elif active_variant == "arachne":
		arachne_state.reset_round()
	else:
		super.reset_round()


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _select_explicit_variant(context):
		return {}
	if active_variant == "molewang":
		return molewang_state.update(delta, context, deps)
	if active_variant == "arachne":
		return arachne_state.update(delta, context, deps)
	return super.update(delta, context, deps)


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _select_explicit_variant(context):
		return {}
	if active_variant == "molewang":
		return molewang_state.register_boss_hit(ball_vel, context, deps)
	if active_variant == "arachne":
		return arachne_state.register_boss_hit(ball_vel, context, deps)
	return super.register_boss_hit(ball_vel, context, deps)


func handle_score_event(scoring_side: String, score_result: Dictionary, deps: Dictionary = {}) -> void:
	if active_variant == "molewang":
		molewang_state.handle_score_event(scoring_side, score_result, deps)
	elif active_variant == "arachne":
		arachne_state.handle_score_event(scoring_side, score_result, deps)


func get_boss_ai_context(stage_background: Object = null) -> Dictionary:
	if active_variant == "molewang":
		return molewang_state.get_boss_ai_context(stage_background)
	if active_variant == "arachne":
		return arachne_state.get_boss_ai_context(stage_background)
	return super.get_boss_ai_context(stage_background)


func get_hud_context(stage_background: Object = null, context: Dictionary = {}) -> Dictionary:
	if active_variant == "molewang":
		return molewang_state.get_hud_context(stage_background, context)
	if active_variant == "arachne":
		return arachne_state.get_hud_context(stage_background, context)
	return super.get_hud_context(stage_background, context)


func get_pressure_snapshot(context: Dictionary = {}) -> Dictionary:
	if active_variant == "molewang":
		return molewang_state.get_pressure_snapshot(context)
	if active_variant == "arachne":
		return arachne_state.get_pressure_snapshot(context)
	return super.get_pressure_snapshot(context)


func get_actor_draw_context() -> Dictionary:
	if active_variant == "molewang":
		return molewang_state.get_actor_draw_context()
	if active_variant == "arachne":
		return arachne_state.get_actor_draw_context()
	return super.get_actor_draw_context()


func absorb_chaos_spear_objects(center: Vector2, pull_radius: float, deps: Dictionary = {}) -> Array:
	if active_variant != "arachne" or arachne_state == null:
		return []
	return arachne_state.absorb_chaos_spear_objects(center, pull_radius, deps)


func get_status() -> String:
	return _active_variant_call("get_status", super.get_status())


func is_speed_defense_active() -> bool:
	return bool(_active_variant_call("is_speed_defense_active", super.is_speed_defense_active()))


func is_boss_status_immune() -> bool:
	return bool(_active_variant_call("is_boss_status_immune", super.is_boss_status_immune()))


func get_quake_cooldown() -> float:
	return float(_active_variant_call("get_quake_cooldown", super.get_quake_cooldown()))


func get_boss_special_gauge() -> float:
	return float(_active_variant_call("get_boss_special_gauge", super.get_boss_special_gauge()))


func get_boss_gauge_max() -> float:
	return float(_active_variant_call("get_boss_gauge_max", super.get_boss_gauge_max()))


func get_boss_gauge_progress() -> float:
	return float(_active_variant_call("get_boss_gauge_progress", super.get_boss_gauge_progress()))


func get_water_cannon_delay() -> float:
	return float(_active_variant_call("get_water_cannon_delay", super.get_water_cannon_delay()))


func get_water_cannon_delay_total() -> float:
	return float(_active_variant_call("get_water_cannon_delay_total", super.get_water_cannon_delay_total()))


func defer_water_cannon_after_rock_spawn(delay_sec: float = WATER_CANNON_AFTER_ROCK_SPAWN_GRACE_SEC) -> void:
	if active_variant == "molewang":
		molewang_state.defer_water_cannon_after_rock_spawn(delay_sec)
	elif active_variant == "arachne":
		arachne_state.defer_water_cannon_after_rock_spawn(delay_sec)
	else:
		super.defer_water_cannon_after_rock_spawn(delay_sec)


func _active_variant_call(method_name: String, fallback: Variant) -> Variant:
	var state: Object = null
	if active_variant == "molewang":
		state = molewang_state
	elif active_variant == "arachne":
		state = arachne_state
	if state != null and state.has_method(method_name):
		return state.call(method_name)
	return fallback


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
		active_variant = StageBossVariantCatalog.get_default_variant(2)
		return true
	if not StageBossVariantCatalog.is_ported_variant(2, requested):
		return false
	active_variant = StageBossVariantCatalog.normalize_variant(2, requested)
	return true
