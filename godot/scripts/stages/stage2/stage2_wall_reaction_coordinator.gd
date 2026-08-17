extends RefCounted

const Stage2BorderFlashState := preload("res://scripts/stages/stage2/stage2_border_flash_state.gd")
const Stage2RustleState := preload("res://scripts/stages/stage2/stage2_rustle_state.gd")

const DEFAULT_BORDER_FLASH_DURATION_SEC := 0.22
const SIDE_WALL_BAND_Y := 135.0
const IMPACT_Y_MARGIN := 20.0
const LEFT_IMPACT_X := 18.0
const RIGHT_IMPACT_X := 742.0
const IMPACT_SPEED_REFERENCE := 520.0
const MIN_SPEED_SCALE := 0.55
const MAX_SPEED_SCALE := 1.65
const AMBIENT_LEAF_BURST_COUNT := 2
const LEAF_PARTICLE_BASE_COUNT := 10.0
const LEAF_PARTICLE_SPEED_COUNT := 9.0
const MIN_LEAF_PARTICLE_COUNT := 10
const MAX_LEAF_PARTICLE_COUNT := 26

var border_flash_state: Object = Stage2BorderFlashState.new()


func reset(default_border_flash_duration_sec: float = DEFAULT_BORDER_FLASH_DURATION_SEC) -> void:
	border_flash_state.reset(default_border_flash_duration_sec)


func advance(delta: float) -> void:
	border_flash_state.update(delta)


func is_border_flash_active() -> bool:
	return bool(border_flash_state.is_active())


func get_border_flash_snapshot() -> Dictionary:
	return border_flash_state.get_snapshot()


func resolve_reaction(side: String, impact_y: float, impact_speed: float, field_height: float) -> Dictionary:
	var resolved_side := side
	if resolved_side == "":
		resolved_side = "left"
	if resolved_side not in ["left", "right"]:
		return {
			"accepted": false,
			"side": resolved_side,
		}
	var height: float = max(1.0, field_height)
	var resolved_y: float = clamp(impact_y, IMPACT_Y_MARGIN, height - IMPACT_Y_MARGIN)
	var origin := Vector2(LEFT_IMPACT_X if resolved_side == "left" else RIGHT_IMPACT_X, resolved_y)
	var bush_hit: bool = Stage2RustleState.is_bush_side_wall_hit(resolved_y, height, SIDE_WALL_BAND_Y)
	var speed_scale := 0.0
	var leaf_particle_count := 0
	if bush_hit:
		speed_scale = clamp(abs(impact_speed) / IMPACT_SPEED_REFERENCE, MIN_SPEED_SCALE, MAX_SPEED_SCALE)
		leaf_particle_count = clampi(
			int(round(LEAF_PARTICLE_BASE_COUNT + speed_scale * LEAF_PARTICLE_SPEED_COUNT)),
			MIN_LEAF_PARTICLE_COUNT,
			MAX_LEAF_PARTICLE_COUNT
		)
	return {
		"accepted": true,
		"side": resolved_side,
		"impact_y": resolved_y,
		"origin": origin,
		"bush_hit": bush_hit,
		"speed_scale": speed_scale,
		"ambient_leaf_count": AMBIENT_LEAF_BURST_COUNT if bush_hit else 0,
		"leaf_particle_count": leaf_particle_count,
	}


func trigger(
	side: String,
	impact_y: float,
	impact_speed: float,
	field_height: float,
	ambient_state: Object,
	ambient_layout_helper: Object,
	ambient_payload_factory: Object,
	random_source: RandomNumberGenerator,
	max_ambient_leaf_count: int,
	max_leaf_particle_count: int,
	leaf_particle_life_sec: float
) -> Dictionary:
	var reaction := resolve_reaction(side, impact_y, impact_speed, field_height)
	if not bool(reaction.get("accepted", false)):
		return reaction
	border_flash_state.trigger(
		str(reaction.get("side", "left")),
		float(reaction.get("impact_y", 0.0)),
		DEFAULT_BORDER_FLASH_DURATION_SEC
	)
	if not bool(reaction.get("bush_hit", false)):
		return reaction
	if ambient_state == null or ambient_layout_helper == null or ambient_payload_factory == null or random_source == null:
		return reaction

	var speed_scale: float = float(reaction.get("speed_scale", MIN_SPEED_SCALE))
	ambient_state.raise_excitement(speed_scale)
	for _index in range(int(reaction.get("ambient_leaf_count", 0))):
		ambient_state.append_ambient_leaf(
			ambient_layout_helper,
			ambient_payload_factory,
			max_ambient_leaf_count
		)
	var origin: Vector2 = reaction.get("origin", Vector2.ZERO)
	var resolved_side: String = str(reaction.get("side", "left"))
	for _index in range(int(reaction.get("leaf_particle_count", 0))):
		ambient_state.append_leaf_particle(
			ambient_payload_factory.build_leaf_particle(
				origin,
				resolved_side,
				speed_scale,
				random_source,
				leaf_particle_life_sec
			),
			max_leaf_particle_count
		)
	return reaction
