extends RefCounted

const TetriserTetrominoState := preload("res://scripts/stages/stage6/stage6_tetriser_tetromino_state.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")

const BASE_CELL_SIZE := TetriserTetrominoState.CELL_SIZE
const BASE_RADIUS := 80.0
const KNOCKBACK_SPEED := 12.0
const NORMAL_STUN_FRAMES := 30.0
const SUPER_STUN_FRAMES := 54.0
const KNOCKBACK_FRAMES := 18.0
const KNOCKBACK_DECAY := 0.88
const STATUS_ID := "stun"
const SOURCE := "stage6_tetro_explosion"


func apply(
	center: Vector2,
	cell_size: float,
	super_explosion: bool,
	context: Dictionary,
	deps: Dictionary
) -> bool:
	var player_pos: Vector2 = context.get("player_pos", Vector2(302.5, 690.0))
	var player_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
	var player_center: Vector2 = Rect2(player_pos, player_size).get_center()
	var radius: float = BASE_RADIUS * maxf(0.1, cell_size / BASE_CELL_SIZE)
	if player_center.distance_to(center) > radius:
		return false
	if _is_player_status_immune(deps, context):
		return false

	var direction := -1.0 if player_center.x < center.x else 1.0
	var knock_scale := 2.0 if super_explosion else 1.0
	var knockback_velocity: float = KNOCKBACK_SPEED * knock_scale * direction
	var stun_frames: float = SUPER_STUN_FRAMES if super_explosion else NORMAL_STUN_FRAMES
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"player",
			STATUS_ID,
			stun_frames,
			{"cleansable": true, "visual": SOURCE},
			SOURCE
		)
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(
			knockback_velocity,
			KNOCKBACK_FRAMES,
			KNOCKBACK_DECAY,
			true,
			true
		)
	return true


func _is_player_status_immune(deps: Dictionary, context: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return true

	var mythic_item_runtime: Object = StarpointBonusDropPolicy.get_mythic_item_runtime(deps, context)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		var status_deps: Dictionary = deps.duplicate()
		status_deps["context"] = context
		if context.get("owner", null) is Object:
			status_deps["owner"] = context.get("owner", null)
		if bool(mythic_item_runtime.try_consume_celestial_armor_immunity(SOURCE, STATUS_ID, status_deps)):
			return true
	return false
