extends RefCounted

const DEFAULT_FRAGMENT_MIN_COUNT := 8
const DEFAULT_FRAGMENT_MAX_COUNT := 12
const DEFAULT_FRAGMENT_LIFE_SEC := 45.0 / 60.0
const DEFAULT_FRAGMENT_GRAVITY := 0.5 * 60.0 * 60.0
const DEFAULT_FRAGMENT_BOUNCE := 0.6


func build_fragments(
	rock: Dictionary,
	center: Vector2,
	debris_count: int,
	colors: Array,
	random_source: RandomNumberGenerator,
	config: Dictionary = {}
) -> Array:
	var size: float = float(rock.get("visual_radius", rock.get("radius", 28.0)))
	var count: int = random_source.randi_range(
		int(config.get("fragment_min_count", DEFAULT_FRAGMENT_MIN_COUNT)),
		int(config.get("fragment_max_count", DEFAULT_FRAGMENT_MAX_COUNT))
	)
	var rock_seed: int = int(rock.get("rock_seed", rock.get("seed", 0)))
	var fragment_life_sec: float = float(config.get("fragment_life_sec", DEFAULT_FRAGMENT_LIFE_SEC))
	var fragment_gravity: float = float(config.get("fragment_gravity", DEFAULT_FRAGMENT_GRAVITY))
	var fragment_bounce: float = float(config.get("fragment_bounce", DEFAULT_FRAGMENT_BOUNCE))
	var direction_axis: Vector2 = _get_vector2(config.get("fragment_direction_axis", Vector2.ZERO)).normalized()
	var directional_chance: float = clampf(float(config.get("fragment_directional_chance", 0.0)), 0.0, 1.0)
	var direction_spread: float = maxf(0.0, float(config.get("fragment_direction_spread", PI * 0.35)))
	var speed_min: float = maxf(0.0, float(config.get("fragment_speed_min", 3.0 * 60.0)))
	var speed_max: float = maxf(speed_min, float(config.get("fragment_speed_max", 8.0 * 60.0)))
	var size_min: int = maxi(1, int(config.get("fragment_size_min", 5)))
	var default_size_max: int = maxi(6, int(size / 3.0))
	var size_max: int = maxi(size_min, int(config.get("fragment_size_max", default_size_max)))
	var spawn_spread: float = maxf(0.0, float(config.get("fragment_spawn_spread", 0.0)))
	var fragments: Array = []
	for idx in range(count):
		var velocity: Vector2
		var fragment_pos := center
		var speed: float
		if direction_axis.length_squared() > 0.0001:
			var angle: float
			if random_source.randf() < directional_chance:
				angle = direction_axis.angle() + random_source.randf_range(-direction_spread, direction_spread)
			else:
				angle = random_source.randf_range(0.0, TAU)
			speed = random_source.randf_range(speed_min, speed_max)
			velocity = Vector2.from_angle(angle) * speed
			if spawn_spread > 0.0:
				fragment_pos += Vector2(
					random_source.randf_range(-spawn_spread, spawn_spread),
					random_source.randf_range(-spawn_spread, spawn_spread)
				)
		else:
			var radial_angle: float = TAU * float(idx) / float(count) + random_source.randf_range(-0.3, 0.3)
			speed = random_source.randf_range(speed_min, speed_max)
			velocity = Vector2(
				cos(radial_angle) * speed,
				sin(radial_angle) * speed - random_source.randf_range(2.0, 5.0) * 60.0
			)
		var fragment_color: Color = _pick_fragment_color(colors, random_source)
		fragments.append({
			"pos": fragment_pos,
			"vel": velocity,
			"size": float(random_source.randi_range(size_min, size_max)),
			"color": fragment_color,
			"sprite_index": (rock_seed + idx * 5) % debris_count if debris_count > 0 else -1,
			"rotation": random_source.randf_range(0.0, TAU),
			"spin": deg_to_rad(random_source.randf_range(-15.0, 15.0) * 60.0),
			"gravity": fragment_gravity,
			"life": fragment_life_sec,
			"max_life": fragment_life_sec,
			"bounce": fragment_bounce,
			"can_hit_boss": bool(config.get("fragment_can_hit_boss", false)),
		})
	return fragments


func _pick_fragment_color(colors: Array, random_source: RandomNumberGenerator) -> Color:
	if colors.is_empty():
		return Color(0.42, 0.42, 0.45, 1.0)
	return colors[random_source.randi_range(0, colors.size() - 1)]


func _get_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
