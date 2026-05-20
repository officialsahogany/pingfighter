extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const AIPILL_FLASH_FRAMES := 12.0
const AIPILL_PHASE_ADVANCE_PER_FRAME := 0.18


func start_state() -> Dictionary:
	return {
		"active": true,
		"phase": 0.0,
		"flash_timer_frames": AIPILL_FLASH_FRAMES,
	}


func update_state(
	active: bool,
	phase: float,
	flash_timer_frames: float,
	owner_available: bool,
	special_gauge: float,
	delta: float
) -> Dictionary:
	if not active:
		return clear_state()

	if not owner_available or special_gauge <= 0.0:
		return clear_state()

	var fps_scale: float = delta * 60.0
	return {
		"active": true,
		"phase": fmod(phase + AIPILL_PHASE_ADVANCE_PER_FRAME * fps_scale, TAU),
		"flash_timer_frames": max(0.0, flash_timer_frames - fps_scale),
	}


func apply_update(
	target: Object,
	owner: Object,
	active: bool,
	phase: float,
	flash_timer_frames: float,
	delta: float,
	state_applier: Object
) -> void:
	state_applier.apply_aipill_state(target, update_state(
		active,
		phase,
		flash_timer_frames,
		owner != null,
		float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0)),
		delta
	))


func flash_state(active: bool, phase: float) -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"flash_timer_frames": AIPILL_FLASH_FRAMES,
	}


func clear_state() -> Dictionary:
	return {
		"active": false,
		"phase": 0.0,
		"flash_timer_frames": 0.0,
	}
