extends RefCounted

const BUSH_RANGE := 150.0
const VINE_RANGE := 120.0
const BUSH_NORMAL_AMOUNT := 8.0
const BUSH_DASH_AMOUNT := 15.0
const VINE_NORMAL_AMOUNT := 7.0
const VINE_DASH_AMOUNT := 12.0
const MOVEMENT_THRESHOLD := 2.0
const DASH_DELTA_THRESHOLD := 15.0
const BOSS_VELOCITY_DASH_THRESHOLD := 10.0
const DEFAULT_VIEW_SIZE := Vector2(760.0, 750.0)
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)

var rustle_state: Object = null
var rustle_payload_factory: Object = null


func configure(rustle_state_ref: Object, rustle_payload_factory_ref: Object) -> void:
	rustle_state = rustle_state_ref
	rustle_payload_factory = rustle_payload_factory_ref


func reset() -> void:
	if rustle_state != null:
		rustle_state.reset()


func ensure_layout(width: float, height: float) -> bool:
	if rustle_state == null or rustle_payload_factory == null:
		return false
	return rustle_state.ensure_layout(
		Vector2(max(0.0, width), max(0.0, height)),
		rustle_payload_factory
	)


func update(delta: float, context: Dictionary) -> void:
	if rustle_state == null or int(context.get("current_stage", 1)) != 2:
		return
	ensure_layout(
		float(context.get("width", DEFAULT_VIEW_SIZE.x)),
		float(context.get("height", DEFAULT_VIEW_SIZE.y))
	)

	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_center_x: float = boss_pos.x + float(context.get("boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH)) * 0.5
	var boss_motion: Dictionary = rustle_state.sample_paddle_motion("boss", boss_center_x)
	if bool(boss_motion.get("had_previous", false)):
		var boss_delta_x: float = float(boss_motion.get("delta_x", 0.0))
		if abs(boss_delta_x) > MOVEMENT_THRESHOLD:
			var boss_dash_like: bool = abs(boss_delta_x) > DASH_DELTA_THRESHOLD \
				or abs(float(context.get("boss_vel", 0.0))) > BOSS_VELOCITY_DASH_THRESHOLD
			trigger_bush("boss", boss_center_x, boss_delta_x, boss_dash_like)
			trigger_vine(boss_center_x, boss_delta_x, boss_dash_like)

	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context.get("player_paddle_size", DEFAULT_PLAYER_PADDLE_SIZE),
		DEFAULT_PLAYER_PADDLE_SIZE
	)
	var player_center_x: float = player_pos.x + player_size.x * 0.5
	var player_motion: Dictionary = rustle_state.sample_paddle_motion("player", player_center_x)
	if bool(player_motion.get("had_previous", false)):
		var player_delta_x: float = float(player_motion.get("delta_x", 0.0))
		if abs(player_delta_x) > MOVEMENT_THRESHOLD:
			var dash_value: Variant = context.get("dash_snapshot", {})
			var dash_snapshot: Dictionary = dash_value if dash_value is Dictionary else {}
			var player_dash_like: bool = abs(player_delta_x) > DASH_DELTA_THRESHOLD \
				or bool(dash_snapshot.get("active", false))
			trigger_bush("player", player_center_x, player_delta_x, player_dash_like)

	rustle_state.advance(max(0.0, delta))


func trigger_bush(area: String, paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	if rustle_state != null:
		rustle_state.trigger_bush_reaction(
			area,
			paddle_center_x,
			delta_x,
			dash_like,
			BUSH_RANGE,
			BUSH_NORMAL_AMOUNT,
			BUSH_DASH_AMOUNT
		)


func trigger_vine(paddle_center_x: float, delta_x: float, dash_like: bool) -> void:
	if rustle_state != null:
		rustle_state.trigger_vine_reaction(
			paddle_center_x,
			delta_x,
			dash_like,
			VINE_RANGE,
			VINE_NORMAL_AMOUNT,
			VINE_DASH_AMOUNT
		)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
