extends RefCounted


static func is_bush_side_wall_hit(impact_y: float, field_height: float, side_wall_band_y: float) -> bool:
	var band: float = min(side_wall_band_y, max(20.0, field_height * 0.24))
	return impact_y <= band or impact_y >= field_height - band


static func trigger_bush_rustle(
	rustle_bushes: Array,
	area: String,
	paddle_center_x: float,
	delta_x: float,
	dash_like: bool,
	rustle_range: float,
	normal_amount: float,
	dash_amount: float
) -> void:
	var base_amount: float = dash_amount if dash_like else normal_amount
	var direction: float = 1.0 if delta_x >= 0.0 else -1.0
	var angle_scale: float = 0.60 if dash_like else 0.30
	for idx in range(rustle_bushes.size()):
		var bush: Dictionary = rustle_bushes[idx]
		if str(bush.get("area", "")) != area:
			continue
		var pos: Vector2 = _get_vector2(bush.get("pos", Vector2.ZERO), Vector2.ZERO)
		var distance: float = abs(pos.x - paddle_center_x)
		if distance >= rustle_range:
			continue
		var distance_factor: float = (rustle_range - distance) / rustle_range
		bush["amount"] = max(float(bush.get("amount", 0.0)), distance_factor * base_amount)
		bush["angle"] = direction * angle_scale
		rustle_bushes[idx] = bush


static func trigger_vine_rustle(
	rustle_vines: Array,
	paddle_center_x: float,
	delta_x: float,
	dash_like: bool,
	rustle_range: float,
	normal_amount: float,
	dash_amount: float
) -> void:
	var base_amount: float = dash_amount if dash_like else normal_amount
	var direction: float = 1.0 if delta_x >= 0.0 else -1.0
	var angle_scale: float = 0.62 if dash_like else 0.38
	for idx in range(rustle_vines.size()):
		var vine: Dictionary = rustle_vines[idx]
		var distance: float = abs(float(vine.get("x", 0.0)) - paddle_center_x)
		if distance >= rustle_range:
			continue
		var distance_factor: float = (rustle_range - distance) / rustle_range
		if float(vine.get("amount", 0.0)) <= 0.01:
			vine["phase"] = 0.0
		vine["amount"] = max(float(vine.get("amount", 0.0)), distance_factor * base_amount)
		vine["angle"] = direction * angle_scale
		rustle_vines[idx] = vine


static func decay(rustle_bushes: Array, rustle_vines: Array, delta: float) -> void:
	var bush_decay: float = pow(0.85, delta * 60.0)
	for idx in range(rustle_bushes.size()):
		var bush: Dictionary = rustle_bushes[idx]
		var amount: float = float(bush.get("amount", 0.0)) * bush_decay
		bush["phase"] = float(bush.get("phase", 0.0)) + delta * 7.5
		if amount < 0.08:
			amount = 0.0
			bush["angle"] = 0.0
		bush["amount"] = amount
		rustle_bushes[idx] = bush
	var vine_decay: float = pow(0.88, delta * 60.0)
	for idx in range(rustle_vines.size()):
		var vine: Dictionary = rustle_vines[idx]
		var amount: float = float(vine.get("amount", 0.0)) * vine_decay
		vine["phase"] = float(vine.get("phase", 0.0)) + max(0.0, delta) * 8.0
		if amount < 0.06:
			amount = 0.0
			vine["angle"] = 0.0
		vine["amount"] = amount
		rustle_vines[idx] = vine


static func has_active(rustle_bushes: Array, rustle_vines: Array) -> bool:
	for bush in rustle_bushes:
		if float(bush.get("amount", 0.0)) > 0.05:
			return true
	for vine in rustle_vines:
		if float(vine.get("amount", 0.0)) > 0.05:
			return true
	return false


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
