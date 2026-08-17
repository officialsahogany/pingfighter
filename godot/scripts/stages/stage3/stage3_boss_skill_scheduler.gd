extends RefCounted

const BossSkillParryGate := preload("res://scripts/stages/common/boss_skill_parry_gate.gd")

# Cross-skill scheduling policy for the Stage 3 boss.
#
# Individual skill owners retain their clocks, activation transactions, and
# runtime payloads. This coordinator owns only the shared cooldown fanout,
# pause aliases, one-writer activation priority, and public status priority.

const DEFAULT_BALL_POS := Vector2(380.0, 375.0)


func is_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func update_cooldowns(
	delta: float,
	kuromi_awakened: bool,
	overdrive_active: bool,
	psychoball_state: Object,
	tear_shower_state: Object,
	curse_chest_state: Object,
	tail_whip_state: Object,
	kuromi_eating_state: Object
) -> void:
	psychoball_state.update_cooldown(delta)
	tear_shower_state.update_cooldown(delta)
	curse_chest_state.update_cooldown(delta)
	tail_whip_state.update_cooldown(delta, kuromi_awakened and not overdrive_active)
	kuromi_eating_state.update_cooldown(delta)


func try_activate_skills(
	context: Dictionary,
	deps: Dictionary,
	kuromi_awakening: bool,
	kuromi_awakened: bool,
	overdrive_active: bool,
	tear_shower_state: Object,
	curse_chest_state: Object,
	tail_whip_state: Object,
	now_msec: int = -1
) -> String:
	if kuromi_awakening:
		return ""
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", false)):
		return ""
	if tear_shower_state.is_ready() and not overdrive_active:
		if BossSkillParryGate.try_parry("tear_shower", "환루천우", context, deps):
			tear_shower_state.consume_parried()
			return "tear_shower_parried"
		tear_shower_state.activate(context, deps)
		return "tear_shower"
	if curse_chest_state.is_ready() and not overdrive_active:
		if BossSkillParryGate.try_parry("curse_chest", "주박궤", context, deps):
			curse_chest_state.consume_parried()
			return "curse_chest_parried"
		curse_chest_state.activate(deps)
		return "curse_chest"
	if kuromi_awakened and tail_whip_state.is_ready() and not overdrive_active:
		if BossSkillParryGate.try_parry("tail_whip", "요미편", context, deps):
			tail_whip_state.consume_parried()
			return "tail_whip_parried"
		var activation_msec := now_msec
		if activation_msec < 0:
			activation_msec = Time.get_ticks_msec()
		var ball_pos := _as_vector2(context.get("ball_pos", DEFAULT_BALL_POS), DEFAULT_BALL_POS)
		tail_whip_state.activate(ball_pos, activation_msec)
		return "tail_whip"
	return ""


func resolve_status(
	cooldown_paused: bool,
	kuromi_awakening: bool,
	kuromi_eating_active: bool,
	overdrive_active: bool,
	tail_whip_active: bool,
	curse_phase: String,
	tears_active: bool
) -> String:
	if kuromi_awakening:
		return "kuromi_awakening"
	if kuromi_eating_active:
		return "kuromi_eating"
	if overdrive_active:
		return "psycho_ball"
	if tail_whip_active:
		return "tail_whip"
	if curse_phase != "idle":
		return "curse_chest"
	if tears_active:
		return "tears"
	return "paused" if cooldown_paused else "charging"


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
