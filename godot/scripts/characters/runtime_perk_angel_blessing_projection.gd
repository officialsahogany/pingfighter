extends RefCounted

const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")


static func apply_player_paddle_size_multiplier(blessing_state: Object, current_multiplier: float) -> float:
	return maxf(
		0.1,
		float(current_multiplier) * _get_multiplier(blessing_state, RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE)
	)


static func apply_special_gauge_max(blessing_state: Object, current_max: float) -> float:
	return maxf(
		1.0,
		float(current_max) * _get_multiplier(blessing_state, RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX)
	)


static func apply_active_item_cooldown_msec(blessing_state: Object, current_cooldown_msec: int) -> int:
	var projected: float = float(maxi(0, current_cooldown_msec)) * _get_multiplier(
		blessing_state,
		RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN
	)
	return maxi(0, int(round(projected)))


static func apply_player_skill_cooldown_multiplier(blessing_state: Object, current_multiplier: float) -> float:
	return maxf(
		0.0,
		float(current_multiplier) * _get_multiplier(blessing_state, RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN)
	)


static func apply_dash_recharge_frames(blessing_state: Object, current_frames: float) -> float:
	return maxf(
		RuntimePerkEffectiveLevels.MIN_DASH_RECHARGE_FRAMES,
		float(current_frames) * _get_multiplier(blessing_state, RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN)
	)


static func apply_player_speed_multiplier(blessing_state: Object, current_multiplier: float) -> float:
	return maxf(
		0.0,
		float(current_multiplier) * _get_multiplier(blessing_state, RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED)
	)


static func _get_multiplier(blessing_state: Object, buff_id: String) -> float:
	if blessing_state == null or not blessing_state.has_method("get_multiplier_for_buff"):
		return 1.0
	return maxf(0.0, float(blessing_state.get_multiplier_for_buff(buff_id)))
