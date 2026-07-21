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
# Rider Y-lift for the shoulder-ride (목말) composition: low enough that the
# rider's board/seat hides BEHIND the mount's head (the companion draws in
# front of the rider while mounted), leaving her upper body above his head.
# Tuned against the 목말 reference shot; live-QA adjustable.
const ONIMARU_SADDLE_LIFT_PX := 14.0

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


# Ride-motion tuning: hop-on arc, dismount drop, gait bounce, breath sway,
# and X-follow inertia. All procedural (no art), all delta-driven.
const MOUNT_HOP_SECONDS := 0.28
const DISMOUNT_SECONDS := 0.16
const RIDE_BOUNCE_MOVE_PX := 3.2
const RIDE_BOUNCE_MOVE_HZ := 5.0
const RIDE_BREATH_PX := 1.5
const RIDE_BREATH_HZ := 0.9
const FOLLOW_SMOOTH_PER_SEC := 11.0
const RIDE_MOVE_SPEED_EPSILON := 0.2

var _hop_t := 1.0
var _dismount_t := 1.0
var _ride_clock := 0.0
var _riding_moving := false
var _follow_x := 0.0
var _last_delta := 0.0


func reset() -> void:
	_mounted = false
	_last_rmb_pressed = false
	_hop_t = 1.0
	_dismount_t = 1.0
	_ride_clock = 0.0
	_riding_moving = false
	_last_delta = 0.0


func set_pet_id(pet_id: String) -> void:
	_pet_id = pet_id
	if not MOUNT_SUPPORTED_PET_IDS.has(_pet_id):
		_mounted = false


func is_mounted() -> bool:
	return _mounted


# Animated rider lift: hop-on arc with a small overshoot, then gait bounce
# while the pair moves / gentle breath sway at rest; eased drop on dismount.
func get_rider_lift_px() -> float:
	if _mounted:
		var hop: float = clampf(_hop_t, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - hop, 3.0)
		var overshoot: float = sin(hop * PI) * 0.3 * (1.0 - hop)
		return ONIMARU_SADDLE_LIFT_PX * (eased + overshoot) + _get_ride_bounce_px() * eased
	if _dismount_t < 1.0:
		return ONIMARU_SADDLE_LIFT_PX * pow(1.0 - _dismount_t, 2.0)
	return 0.0


func _get_ride_bounce_px() -> float:
	if _riding_moving:
		return RIDE_BOUNCE_MOVE_PX * absf(sin(_ride_clock * TAU * RIDE_BOUNCE_MOVE_HZ * 0.5))
	return RIDE_BREATH_PX * 0.5 * (1.0 + sin(_ride_clock * TAU * RIDE_BREATH_HZ * 0.5))


# Ticks the toggle + ride motion clocks. Call once per companion update frame
# while the companion is in its active (non-egg) state; pass
# companion_active=false to force a dismount (pet incapacitated / despawned).
func advance(owner: Object, companion_pos: Vector2, companion_active: bool, input_blocked: bool = false, delta: float = 0.0) -> Dictionary:
	var result := {"toggled": false, "mounted": _mounted}
	_last_delta = maxf(delta, 0.0)
	if _mounted:
		_hop_t = minf(1.0, _hop_t + _last_delta / MOUNT_HOP_SECONDS)
		_ride_clock += _last_delta
		_riding_moving = absf(float(BattleSceneOwnerReader.get_value(owner, "player_speed", 0.0))) > RIDE_MOVE_SPEED_EPSILON
	else:
		_dismount_t = minf(1.0, _dismount_t + _last_delta / DISMOUNT_SECONDS)
	if not MOUNT_SUPPORTED_PET_IDS.has(_pet_id) or not companion_active:
		if _mounted:
			_dismount()
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
		_dismount()
		result["toggled"] = true
		result["mounted"] = false
		return result
	var player_center_x: float = _get_player_center_x(owner)
	if absf(player_center_x - companion_pos.x) > MOUNT_PROXIMITY_PX:
		return result
	_mounted = true
	_hop_t = 0.0
	_ride_clock = 0.0
	_follow_x = companion_pos.x
	result["toggled"] = true
	result["mounted"] = true
	return result


func _dismount() -> void:
	_mounted = false
	_dismount_t = 0.0


func has_companion_position_override() -> bool:
	return _mounted


# Ground pet keeps its lane Y -- only X follows the rider (companion
# teleport/reposition locomotion trap). The X-follow uses exponential
# smoothing so the mount trails the rider with a little inertia instead of
# snapping rigidly (this also drives the walk animator with real movement).
func get_companion_position_override(owner: Object, current: Vector2) -> Vector2:
	if not _mounted:
		return current
	var target_x: float = _get_player_center_x(owner)
	var blend: float = 1.0 - exp(-FOLLOW_SMOOTH_PER_SEC * _last_delta)
	_follow_x = lerpf(_follow_x, target_x, blend)
	return Vector2(_follow_x, current.y)


func _get_player_center_x(owner: Object) -> float:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	var paddle_size: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_paddle_size", Vector2(155.0, 50.0))
	return player_pos.x + paddle_size.x * 0.5
