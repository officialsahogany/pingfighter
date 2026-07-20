extends RefCounted

# 수호령 탑승 (socket composition contract, lane C pilot -- 오니마루).
#
# Interaction: while the companion is active and the player stands within
# MOUNT_PROXIMITY_PX of it, a bare right-click (no S/down held -- S+RMB stays
# reserved for Smasher Overdrive) toggles mount. While mounted:
#  - the companion position-overrides to the player's center X, KEEPING its
#    own lane Y (ground-pet locomotion trap: X changes only)
#  - companion body-hit / defense is suppressed (parked != disabled trap)
#  - the rider (player sprite stack: body + glow + parts) is lifted by the
#    companion's saddle height so she stands on the mount's back
#
# Edge detection polls Input directly with module-local previous-state (the
# same pattern smasher_input_reader uses) -- it never consumes another
# reader's stateful edges.
#
# Every round/result/stage reset must call reset(); a mount surviving a round
# boundary is a state leak (boss-skill cleanup trap family).

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const MOUNT_PROXIMITY_PX := 78.0
const MOUNT_SUPPORTED_PET_IDS := ["onimaru"]
# Saddle height above the companion's ground anchor, in companion draw px
# (authored from the onimaru sheets' back line; consumed as a rider Y-lift).
const ONIMARU_SADDLE_LIFT_PX := 34.0

var _mounted := false
var _last_rmb_pressed := false
var _pet_id := ""
# Test seam: object exposing is_rmb_pressed() / is_down_pressed(). Headless
# smokes inject it because real Input cannot be driven there; live play
# leaves it null and polls Input directly.
var _input_probe: Object = null


func set_input_probe(probe: Object) -> void:
	_input_probe = probe


func _is_rmb_pressed() -> bool:
	if _input_probe != null and _input_probe.has_method("is_rmb_pressed"):
		return bool(_input_probe.is_rmb_pressed())
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _is_down_pressed() -> bool:
	if _input_probe != null and _input_probe.has_method("is_down_pressed"):
		return bool(_input_probe.is_down_pressed())
	return Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)


func reset() -> void:
	_mounted = false
	_last_rmb_pressed = false


func set_pet_id(pet_id: String) -> void:
	_pet_id = pet_id
	if not MOUNT_SUPPORTED_PET_IDS.has(_pet_id):
		_mounted = false


func is_mounted() -> bool:
	return _mounted


func get_rider_lift_px() -> float:
	return ONIMARU_SADDLE_LIFT_PX if _mounted else 0.0


# Ticks the toggle. Call once per companion update frame while the companion
# is in its active (non-egg) state; pass companion_active=false to force a
# dismount (e.g. the pet got incapacitated or despawned).
func advance(owner: Object, companion_pos: Vector2, companion_active: bool, input_blocked: bool = false) -> Dictionary:
	var result := {"toggled": false, "mounted": _mounted}
	if not MOUNT_SUPPORTED_PET_IDS.has(_pet_id) or not companion_active:
		if _mounted:
			_mounted = false
			result["toggled"] = true
		result["mounted"] = _mounted
		_last_rmb_pressed = _is_rmb_pressed()
		return result

	var rmb_pressed: bool = _is_rmb_pressed()
	var rmb_just_pressed: bool = rmb_pressed and not _last_rmb_pressed
	_last_rmb_pressed = rmb_pressed
	if input_blocked or not rmb_just_pressed:
		return result
	# S+RMB is Smasher Overdrive -- never steal that chord.
	if _is_down_pressed():
		return result
	if _mounted:
		_mounted = false
		result["toggled"] = true
		result["mounted"] = false
		return result
	var player_center_x: float = _get_player_center_x(owner)
	if absf(player_center_x - companion_pos.x) > MOUNT_PROXIMITY_PX:
		return result
	_mounted = true
	result["toggled"] = true
	result["mounted"] = true
	return result


func has_companion_position_override() -> bool:
	return _mounted


# Ground pet keeps its lane Y -- only X follows the rider (companion
# teleport/reposition locomotion trap).
func get_companion_position_override(owner: Object, current: Vector2) -> Vector2:
	if not _mounted:
		return current
	return Vector2(_get_player_center_x(owner), current.y)


func _get_player_center_x(owner: Object) -> float:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	var paddle_size: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_paddle_size", Vector2(155.0, 50.0))
	return player_pos.x + paddle_size.x * 0.5
