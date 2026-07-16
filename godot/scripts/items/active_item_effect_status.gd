extends RefCounted

const VITAMIN_PILL_SPEED_MULTIPLIER := 1.5


func can_store_item(item_name: String, active_flags: Dictionary) -> bool:
	if bool(active_flags.get("aipill_active", false)):
		return false
	if item_name == "long_boost" and bool(active_flags.get("long_boost_active", false)):
		return false
	# milk_bottle intentionally has NO active-state store gate: Milku continuously
	# produces milk, and the paddle buff now stacks (capped) per use, so a second+
	# bottle must remain collectable while milk_bottle_active is true.
	if item_name == "vitamin_pill" and bool(active_flags.get("vitamin_pill_active", false)):
		return false
	if item_name == "strange_vial" and bool(active_flags.get("strange_vial_active", false)):
		return false
	if item_name == "doping_potion" and bool(active_flags.get("doping_potion_active", false)):
		return false
	if item_name == "stopwatch" and bool(active_flags.get("stopwatch_active", false)):
		return false
	if item_name == "magnet_field" and bool(active_flags.get("magnet_field_active", false)):
		return false
	if item_name == "hologram_disk" and bool(active_flags.get("hologram_disk_active", false)):
		return false
	if item_name == "holy_barrier" and bool(active_flags.get("holy_barrier_active", false)):
		return false
	if item_name == "dash_boost" and bool(active_flags.get("dash_boost_active", false)):
		return false
	if item_name == "wall" and bool(active_flags.get("brick_wall_installing", false)):
		return false
	return true


func has_field_effects(effect_flags: Dictionary) -> bool:
	return (
		bool(effect_flags.get("has_pickup_particles", false))
		or bool(effect_flags.get("has_regeneration_potion_rings", false))
		or bool(effect_flags.get("has_regeneration_potion_particles", false))
		or bool(effect_flags.get("stopwatch_active", false))
		or bool(effect_flags.get("magnet_field_active", false))
		or bool(effect_flags.get("has_magnet_field_particles", false))
		or bool(effect_flags.get("hologram_disk_active", false))
		or bool(effect_flags.get("has_hologram_decoys", false))
		or bool(effect_flags.get("has_hologram_decoy_pop_particles", false))
		or bool(effect_flags.get("holy_barrier_active", false))
		or bool(effect_flags.get("has_holy_barrier_particles", false))
		or bool(effect_flags.get("dash_boost_active", false))
		or bool(effect_flags.get("has_dash_boost_particles", false))
		or bool(effect_flags.get("brick_wall_installing", false))
		or bool(effect_flags.get("has_brick_walls", false))
		or bool(effect_flags.get("has_brick_particles", false))
		or bool(effect_flags.get("has_trampolines", false))
		or bool(effect_flags.get("has_trampoline_particles", false))
		or bool(effect_flags.get("long_boost_active", false))
		or bool(effect_flags.get("vitamin_pill_active", false))
		or bool(effect_flags.get("strange_vial_active", false))
		or bool(effect_flags.get("doping_potion_active", false))
	)


func get_player_speed_multiplier(
	vitamin_pill_active: bool,
	vitamin_pill_timer_frames: float,
	strange_vial_active: bool,
	strange_vial_timer_frames: float,
	strange_vial_speed_multiplier: float
) -> float:
	var multiplier: float = 1.0
	if vitamin_pill_active and vitamin_pill_timer_frames > 0.0:
		multiplier *= VITAMIN_PILL_SPEED_MULTIPLIER
	if strange_vial_active and strange_vial_timer_frames > 0.0:
		multiplier *= strange_vial_speed_multiplier
	return multiplier


func is_time_frozen(stopwatch_active: bool, stopwatch_timer_frames: float) -> bool:
	return stopwatch_active and stopwatch_timer_frames > 0.0


func is_active(flag: bool) -> bool:
	return flag
