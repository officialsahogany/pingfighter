extends RefCounted

const BUILDING_DURATION := 1.0
const WARP_DURATION := 1.0

var building_active := false
var building_phase := ""
var building_timer := 0.0
var building_target: Dictionary = {}
var building_player_pos := Vector2.ZERO
var building_lingpet_pos := Vector2.ZERO
var warp_active := false
var warp_phase := ""
var warp_timer := 0.0


func start_building(
	phase: String,
	target: Dictionary,
	player_pos: Vector2,
	lingpet_pos: Vector2
) -> bool:
	if building_active:
		return false
	building_active = true
	building_phase = phase
	building_timer = 0.0
	building_target = target.duplicate(true)
	building_player_pos = player_pos
	building_lingpet_pos = lingpet_pos
	return true


func advance_building(delta: float) -> bool:
	if not building_active:
		return false
	building_timer = min(BUILDING_DURATION, building_timer + max(0.0, delta))
	return building_timer >= BUILDING_DURATION


func clear_building() -> void:
	building_active = false
	building_phase = ""
	building_timer = 0.0
	building_target.clear()
	building_player_pos = Vector2.ZERO
	building_lingpet_pos = Vector2.ZERO


func get_building_progress() -> float:
	if not building_active:
		return 0.0
	return clampf(building_timer / BUILDING_DURATION, 0.0, 1.0)


func get_building_actor_alpha(progress: float) -> float:
	var eased := _smooth_unit(progress)
	return eased if building_phase == "return" else 1.0 - eased


func get_building_actor_lift(progress: float) -> float:
	var eased := _smooth_unit(progress)
	return -34.0 * (1.0 - eased) if building_phase == "return" else -42.0 * eased


func start_warp(phase: String) -> bool:
	if warp_active:
		return false
	warp_active = true
	warp_phase = phase
	warp_timer = 0.0
	return true


func advance_warp(delta: float) -> bool:
	if not warp_active:
		return false
	warp_timer = min(WARP_DURATION, warp_timer + max(0.0, delta))
	return warp_timer >= WARP_DURATION


func clear_warp() -> void:
	warp_active = false
	warp_phase = ""
	warp_timer = 0.0


func get_warp_progress() -> float:
	if not warp_active:
		return 0.0
	return clampf(warp_timer / WARP_DURATION, 0.0, 1.0)


func get_warp_actor_alpha(progress: float) -> float:
	var eased := _smooth_unit(progress)
	return eased if warp_phase == "arrive" else 1.0 - eased


func get_warp_actor_lift(progress: float) -> float:
	var eased := _smooth_unit(progress)
	return -42.0 * (1.0 - eased) if warp_phase == "arrive" else -48.0 * eased


func reset() -> void:
	clear_building()
	clear_warp()


static func _smooth_unit(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	return clamped_value * clamped_value * (3.0 - 2.0 * clamped_value)
