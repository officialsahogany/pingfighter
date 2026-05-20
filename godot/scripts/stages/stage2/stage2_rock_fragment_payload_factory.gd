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
	var fragments: Array = []
	for idx in range(count):
		var angle: float = TAU * float(idx) / float(count) + random_source.randf_range(-0.3, 0.3)
		var speed: float = random_source.randf_range(3.0, 8.0) * 60.0
		var max_fragment_size: int = maxi(6, int(size / 3.0))
		var fragment_color: Color = _pick_fragment_color(colors, random_source)
		fragments.append({
			"pos": center,
			"vel": Vector2(
				cos(angle) * speed,
				sin(angle) * speed - random_source.randf_range(2.0, 5.0) * 60.0
			),
			"size": float(random_source.randi_range(5, max_fragment_size)),
			"color": fragment_color,
			"sprite_index": (rock_seed + idx * 5) % debris_count if debris_count > 0 else -1,
			"rotation": random_source.randf_range(0.0, TAU),
			"spin": deg_to_rad(random_source.randf_range(-15.0, 15.0) * 60.0),
			"gravity": fragment_gravity,
			"life": fragment_life_sec,
			"max_life": fragment_life_sec,
			"bounce": fragment_bounce,
		})
	return fragments


func _pick_fragment_color(colors: Array, random_source: RandomNumberGenerator) -> Color:
	if colors.is_empty():
		return Color(0.42, 0.42, 0.45, 1.0)
	return colors[random_source.randi_range(0, colors.size() - 1)]
