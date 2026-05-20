extends RefCounted


static func append_limited(target: Array, value: Dictionary, limit: int) -> void:
	target.append(value)
	while target.size() > max(1, limit):
		target.pop_front()


static func get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


static func get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func get_pistol_cooldown_frames(
	weapon_id: String,
	doping_context: Dictionary,
	doping_active: bool,
	base_cooldown_frames: float,
	commando_pistol_cooldown_frames: float,
	doping_pistol_cooldown_frames: float
) -> float:
	if doping_active:
		return float(doping_context.get("pistol_cooldown_frames", doping_pistol_cooldown_frames))
	if weapon_id == "commando_pistol":
		return commando_pistol_cooldown_frames
	return base_cooldown_frames


static func normalize_doping_potion_context(context: Dictionary, defaults: Dictionary = {}) -> Dictionary:
	var default_head_leg_multiplier: float = float(defaults.get("head_leg_multiplier", 2.0))
	var default_cooldown_frames: float = float(defaults.get("pistol_cooldown_frames", 30.0))
	var default_control_lock_frames: float = float(defaults.get("pistol_control_lock_frames", 9.0))
	var default_speed_multiplier: float = float(defaults.get("pistol_speed_multiplier", 1.2))
	var active: bool = bool(context.get(
		"active",
		context.get("active_item_doping_potion_active", false)
	))
	var head_leg_multiplier: float = float(context.get(
		"head_leg_multiplier",
		context.get("active_item_doping_potion_head_leg_multiplier", default_head_leg_multiplier if active else 1.0)
	))
	var cooldown_frames: float = float(context.get(
		"pistol_cooldown_frames",
		context.get("active_item_doping_potion_pistol_cooldown_frames", default_cooldown_frames)
	))
	var control_lock_frames: float = float(context.get(
		"pistol_control_lock_frames",
		context.get("active_item_doping_potion_pistol_control_lock_frames", default_control_lock_frames)
	))
	var speed_multiplier: float = float(context.get(
		"pistol_speed_multiplier",
		context.get("active_item_doping_potion_pistol_speed_multiplier", default_speed_multiplier if active else 1.0)
	))
	return {
		"active": active,
		"head_leg_multiplier": max(0.0, head_leg_multiplier),
		"pistol_cooldown_frames": max(1.0, cooldown_frames),
		"pistol_control_lock_frames": max(0.0, control_lock_frames),
		"pistol_speed_multiplier": max(0.01, speed_multiplier),
	}


static func get_doping_potion_context_from_deps(deps: Dictionary, defaults: Dictionary = {}) -> Dictionary:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_doping_potion_context"):
			return normalize_doping_potion_context(active_item_runtime.get_doping_potion_context(), defaults)
		if active_item_runtime.has_method("is_doping_potion_active"):
			return normalize_doping_potion_context({
				"active": bool(active_item_runtime.is_doping_potion_active()),
			}, defaults)
	var context_value: Variant = deps.get("active_item_doping_potion_context", {})
	if context_value is Dictionary:
		return normalize_doping_potion_context(context_value, defaults)
	if deps.has("active_item_doping_potion_active"):
		return normalize_doping_potion_context(deps, defaults)
	return normalize_doping_potion_context({}, defaults)


static func apply_doping_potion_to_pistol_config(
	config: Dictionary,
	doping_context: Dictionary,
	defaults: Dictionary = {}
) -> void:
	if not bool(doping_context.get("active", false)):
		config["active_item_doping_potion_active"] = false
		return
	config["active_item_doping_potion_active"] = true
	config["active_item_doping_potion_head_leg_multiplier"] = float(doping_context.get(
		"head_leg_multiplier",
		defaults.get("head_leg_multiplier", 2.0)
	))
	config["active_item_doping_potion_pistol_cooldown_frames"] = float(doping_context.get(
		"pistol_cooldown_frames",
		defaults.get("pistol_cooldown_frames", 30.0)
	))
	config["active_item_doping_potion_pistol_control_lock_frames"] = float(doping_context.get(
		"pistol_control_lock_frames",
		defaults.get("pistol_control_lock_frames", 9.0)
	))
	config["active_item_doping_potion_pistol_speed_multiplier"] = float(doping_context.get(
		"pistol_speed_multiplier",
		defaults.get("pistol_speed_multiplier", 1.2)
	))


static func is_pistol_weapon(weapon_id: String, base_weapon_id: String = "pistol") -> bool:
	return weapon_id == base_weapon_id or weapon_id == "commando_pistol"


static func get_pistol_hit_doping_multiplier(
	projectile: Dictionary,
	context: Dictionary,
	default_head_leg_multiplier: float
) -> float:
	var active: bool = bool(projectile.get(
		"active_item_doping_potion_active",
		context.get("active_item_doping_potion_active", false)
	))
	if not active:
		return 1.0
	return max(0.0, float(projectile.get(
		"active_item_doping_potion_head_leg_multiplier",
		context.get("active_item_doping_potion_head_leg_multiplier", default_head_leg_multiplier)
	)))


static func get_pistol_hit_chances(
	context: Dictionary,
	doping_multiplier: float,
	default_head_chance: float,
	default_leg_chance: float
) -> Dictionary:
	var head_chance: float = clamp(
		float(context.get("commando_pistol_head_chance", default_head_chance)) * doping_multiplier,
		0.0,
		1.0
	)
	var leg_chance: float = clamp(
		float(context.get("commando_pistol_leg_chance", default_leg_chance)) * doping_multiplier,
		0.0,
		1.0
	)
	if head_chance + leg_chance > 0.95:
		var scale := 0.95 / (head_chance + leg_chance)
		head_chance *= scale
		leg_chance *= scale
	return {
		"head_chance": head_chance,
		"leg_chance": leg_chance,
	}


static func get_pistol_shot_roll(projectile: Dictionary, context: Dictionary) -> float:
	var value: Variant = projectile.get("shot_roll", projectile.get(
		"pistol_shot_roll",
		context.get("commando_pistol_shot_roll", -1.0)
	))
	if value is int or value is float:
		var numeric_value: float = float(value)
		if numeric_value >= 0.0 and numeric_value <= 1.0:
			return numeric_value
	return randf()


static func get_target_reached_expire_reason(weapon_id: String, profile: Dictionary) -> String:
	if weapon_id == "bazooka":
		return ""
	if str(profile.get("kind", "")) in ["rocket", "support", "drone"]:
		return "expired"
	return ""


static func is_fire_support_weapon(weapon_id: String) -> bool:
	return weapon_id == "fire_support"


static func is_net_gun_weapon(weapon_id: String) -> bool:
	return weapon_id == "net_gun"


static func support_bomb_target_y_already_reached(projectile: Dictionary) -> bool:
	return float(projectile.get("support_target_y_reached", 0.0)) > 0.0


static func projectile_life_expired(projectile: Dictionary) -> bool:
	return float(projectile.get("life_frames", 0.0)) <= 0.0


static func get_projectile_target(projectile: Dictionary, fallback_target: Vector2) -> Vector2:
	return get_vector2(projectile.get("target", fallback_target), fallback_target)


static func get_projectile_weapon_id(projectile: Dictionary, fallback_weapon_id: String) -> String:
	return str(projectile.get("weapon_id", fallback_weapon_id))


static func get_projectile_kind(projectile: Dictionary, fallback_kind: String = "") -> String:
	return str(projectile.get("kind", fallback_kind))


static func get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
