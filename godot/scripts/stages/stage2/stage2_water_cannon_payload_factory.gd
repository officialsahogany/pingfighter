extends RefCounted

const DEFAULT_ROCK_FRAGMENT_MIN_COUNT := 20
const DEFAULT_ROCK_FRAGMENT_MAX_COUNT := 25
const DEFAULT_WATER_SPLASH_MIN_COUNT := 15
const DEFAULT_WATER_SPLASH_MAX_COUNT := 20
const DEFAULT_ROCK_FRAGMENT_LIFE_SEC := 100.0 / 60.0
const DEFAULT_WATER_SPLASH_LIFE_SEC := 60.0 / 60.0
const DEFAULT_ROCK_FRAGMENT_GRAVITY := 0.5 * 60.0 * 60.0
const DEFAULT_WATER_SPLASH_GRAVITY := 0.3 * 60.0 * 60.0
const DEFAULT_ROCK_FRAGMENT_DIRECTIONAL_CHANCE := 0.65
const DEFAULT_ROCK_FRAGMENT_CONE_HALF_ANGLE := PI * 0.35
const DEFAULT_ROCK_FRAGMENT_CONE_MIN_ANGLE := PI * 0.15
const DEFAULT_ROCK_FRAGMENT_CONE_MAX_ANGLE := PI * 0.85
const DEFAULT_ROCK_FRAGMENT_SPEED_MIN_PER_FRAME := 5.6
const DEFAULT_ROCK_FRAGMENT_SPEED_MAX_PER_FRAME := 10.1
const DEFAULT_ROCK_FRAGMENT_SIZE_MIN := 10
const DEFAULT_ROCK_FRAGMENT_SIZE_MAX := 22
const GOLDEN_ROCK_DEBRIS_INDICES := [10, 15]


func build_payloads(
	rock: Dictionary,
	center: Vector2,
	debris_count: int,
	random_source: RandomNumberGenerator,
	config: Dictionary = {}
) -> Array:
	var rock_size: float = float(rock.get("visual_radius", rock.get("radius", 28.0)))
	var payloads: Array = build_water_splashes(center, rock_size, random_source, config)
	payloads.append_array(build_rock_fragments(rock, center, rock_size, debris_count, random_source, config))
	return payloads


func build_rock_fragments(
	rock: Dictionary,
	center: Vector2,
	rock_size: float,
	debris_count: int,
	random_source: RandomNumberGenerator,
	config: Dictionary = {}
) -> Array:
	var rock_seed: int = int(rock.get("rock_seed", rock.get("seed", 0)))
	var rock_count: int = random_source.randi_range(
		int(config.get("rock_fragment_min_count", DEFAULT_ROCK_FRAGMENT_MIN_COUNT)),
		int(config.get("rock_fragment_max_count", DEFAULT_ROCK_FRAGMENT_MAX_COUNT))
	)
	var rock_life_sec: float = float(config.get("rock_fragment_life_sec", DEFAULT_ROCK_FRAGMENT_LIFE_SEC))
	var rock_gravity: float = float(config.get("rock_fragment_gravity", DEFAULT_ROCK_FRAGMENT_GRAVITY))
	var fragments: Array = []
	for idx in range(rock_count):
		var angle: float
		if random_source.randf() < DEFAULT_ROCK_FRAGMENT_DIRECTIONAL_CHANCE:
			angle = random_source.randf_range(
				DEFAULT_ROCK_FRAGMENT_CONE_MIN_ANGLE,
				DEFAULT_ROCK_FRAGMENT_CONE_MAX_ANGLE
			)
		else:
			angle = random_source.randf_range(0.0, TAU)
		var speed: float = random_source.randf_range(
			DEFAULT_ROCK_FRAGMENT_SPEED_MIN_PER_FRAME,
			DEFAULT_ROCK_FRAGMENT_SPEED_MAX_PER_FRAME
		) * 60.0
		var fragment_size: float = float(random_source.randi_range(
			DEFAULT_ROCK_FRAGMENT_SIZE_MIN,
			DEFAULT_ROCK_FRAGMENT_SIZE_MAX
		))
		fragments.append({
			"pos": center + Vector2(
				random_source.randf_range(-rock_size / 3.0, rock_size / 3.0),
				random_source.randf_range(-rock_size / 3.0, rock_size / 3.0)
			),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": rock_life_sec,
			"max_life": rock_life_sec,
			"radius": fragment_size,
			"hit_radius": fragment_size * 0.5,
			"gravity": rock_gravity,
			"stone": true,
			"can_hit_player": true,
			"hit_cooldown": 0.0,
			"rot": random_source.randf_range(0.0, TAU),
			"spin": deg_to_rad(random_source.randf_range(-25.0, 25.0) * 60.0),
			"sprite_index": _select_rock_debris_index(rock, rock_size, rock_seed, idx, debris_count),
		})
	return fragments


func build_water_splashes(
	center: Vector2,
	rock_size: float,
	random_source: RandomNumberGenerator,
	config: Dictionary = {}
) -> Array:
	var water_count: int = random_source.randi_range(
		int(config.get("water_splash_min_count", DEFAULT_WATER_SPLASH_MIN_COUNT)),
		int(config.get("water_splash_max_count", DEFAULT_WATER_SPLASH_MAX_COUNT))
	)
	var water_life_sec: float = float(config.get("water_splash_life_sec", DEFAULT_WATER_SPLASH_LIFE_SEC))
	var water_gravity: float = float(config.get("water_splash_gravity", DEFAULT_WATER_SPLASH_GRAVITY))
	var splashes: Array = []
	for _idx in range(water_count):
		var angle: float = random_source.randf_range(0.0, TAU)
		var speed: float = random_source.randf_range(3.4, 7.8) * 60.0
		var splash_size: float = float(random_source.randi_range(5, 12))
		splashes.append({
			"pos": center + Vector2(
				random_source.randf_range(-rock_size / 2.0, rock_size / 2.0),
				random_source.randf_range(-rock_size / 2.0, rock_size / 2.0)
			),
			"vel": Vector2(
				cos(angle) * speed,
				sin(angle) * speed - random_source.randf_range(2.0, 5.0) * 60.0
			),
			"life": water_life_sec,
			"max_life": water_life_sec,
			"radius": splash_size,
			"hit_radius": 0.0,
			"gravity": water_gravity,
			"stone": false,
			"can_hit_player": false,
			"hit_cooldown": 0.0,
			"rot": 0.0,
			"spin": 0.0,
			"sprite_index": -1,
		})
	return splashes


func _select_rock_debris_index(
	rock: Dictionary,
	rock_size: float,
	rock_seed: int,
	index: int,
	debris_count: int
) -> int:
	if debris_count <= 0:
		return -1
	if bool(rock.get("is_golden", false)):
		return int(GOLDEN_ROCK_DEBRIS_INDICES[index % GOLDEN_ROCK_DEBRIS_INDICES.size()]) % debris_count
	return (int(rock_size) + rock_seed + index * 7) % debris_count
