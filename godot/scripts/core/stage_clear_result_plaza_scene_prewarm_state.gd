extends RefCounted

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")

var _prewarm_complete: bool = false
var _prewarm_stage: int = -1
var _background_prewarm_enabled: bool = true


func reset() -> void:
	_prewarm_complete = false
	_prewarm_stage = -1


func set_background_prewarm_enabled(enabled: bool) -> void:
	_background_prewarm_enabled = enabled
	if not enabled:
		reset()


func get_status() -> Dictionary:
	return {
		"plaza_prewarm_complete": _prewarm_complete,
		"plaza_prewarm_stage": _prewarm_stage,
	}


func prewarm_assets_step(current_stage: int) -> bool:
	if not _background_prewarm_enabled:
		return false
	var stage_id: int = maxi(1, current_stage)
	if _prewarm_complete and _prewarm_stage == stage_id:
		return true
	_prewarm_stage = stage_id
	_prewarm_complete = bool(PlazaScene.prewarm_assets_threaded_step(stage_id))
	return _prewarm_complete


func ensure_assets_ready(current_stage: int) -> bool:
	var stage_id: int = maxi(1, current_stage)
	if _prewarm_complete and _prewarm_stage == stage_id:
		return true
	_prewarm_stage = stage_id
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(stage_id)):
		guard += 1
		if guard > 256:
			push_warning("Timed out while prewarming plaza assets for stage %d" % stage_id)
			return false
	_prewarm_complete = true
	return true
