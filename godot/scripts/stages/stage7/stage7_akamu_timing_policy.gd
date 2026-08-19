extends RefCounted

# Pure cross-feature timing policy for Stage 7 Akamu Rigo.
#
# This owner centralizes external freeze/pause vocabulary and precedence. It is
# intentionally stateless: Stage7AkamuState still owns the resulting live
# pause snapshot that it publishes to HUD and presentation consumers.


func is_gameplay_timing_frozen(context: Dictionary) -> bool:
	return not bool(context.get("ball_active", true)) \
		or bool(context.get("waiting_for_serve", false)) \
		or bool(context.get("gameplay_timing_frozen", false)) \
		or bool(context.get("stopwatch_freeze_active", false)) \
		or bool(context.get("active_item_stopwatch_freeze_active", false)) \
		or bool(context.get("perk_resume_freeze_active", false)) \
		or bool(context.get("power_smashing_freeze_active", false)) \
		or bool(context.get("viper_dmk_freeze_active", false)) \
		or bool(context.get("viper_nerve_strike_freeze_active", false))


func is_context_boss_skill_cooldown_paused(context: Dictionary) -> bool:
	if bool(context.get("lingpet_star_coil_freeze_boss_skill_cd", false)):
		return true
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func is_boss_skill_cooldown_paused(context: Dictionary, deps: Dictionary = {}) -> bool:
	if is_context_boss_skill_cooldown_paused(context):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not active_item_runtime.has_method("get_boss_ai_context"):
		return false
	var boss_context: Dictionary = active_item_runtime.get_boss_ai_context()
	return bool(boss_context.get(
		"active_item_boss_skill_cooldown_paused",
		boss_context.get("active_item_tear_gas_cooldown_pause_active", false)
	))
