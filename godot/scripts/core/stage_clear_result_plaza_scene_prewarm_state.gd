extends RefCounted

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

var _prewarm_complete: bool = false
var _prewarm_stage: int = -1
var _background_prewarm_enabled: bool = true
var _last_readiness_rejection_reason: String = "not_started"
var _entry_forced: bool = false
var _printed_entry_yield_reason: String = ""


func reset() -> void:
	_prewarm_complete = false
	_prewarm_stage = -1
	_last_readiness_rejection_reason = "not_started"
	_entry_forced = false
	_printed_entry_yield_reason = ""


func set_background_prewarm_enabled(enabled: bool) -> void:
	_background_prewarm_enabled = enabled
	if not enabled:
		reset()


func get_status() -> Dictionary:
	var gpu_status := BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status()
	var status := {
		"plaza_prewarm_complete": _prewarm_complete,
		"plaza_prewarm_stage": _prewarm_stage,
		"plaza_readiness_rejection_reason": _last_readiness_rejection_reason,
		"plaza_gpu_prewarm_complete": bool(gpu_status.get("complete", false)),
		"plaza_gpu_prewarm_drawn_layer_count": int(gpu_status.get("drawn_layer_count", 0)),
		"plaza_gpu_prewarm_expected_layer_count": int(gpu_status.get("expected_layer_count", 0)),
		"plaza_gpu_prewarm_post_draw_flush_count": int(gpu_status.get("post_draw_flush_count", 0)),
		"plaza_gpu_prewarm_required_post_draw_flush_count": int(gpu_status.get("required_post_draw_flush_count", 0)),
		"plaza_gpu_prewarm_render_target_size": gpu_status.get("render_target_size", Vector2.ZERO),
		"plaza_gpu_prewarm_in_bounds_layer_count": int(gpu_status.get("in_bounds_layer_count", 0)),
		"plaza_gpu_prewarm_sealed_texture_count": int(gpu_status.get("sealed_texture_count", 0)),
		"plaza_gpu_prewarm_texture_identity_match": bool(gpu_status.get("texture_identity_match", false)),
	}
	return status


func prewarm_assets_step(current_stage: int, owner: Object = null) -> bool:
	if not _background_prewarm_enabled:
		_last_readiness_rejection_reason = "background_prewarm_disabled"
		return false
	var stage_id: int = maxi(1, current_stage)
	if not (_prewarm_complete and _prewarm_stage == stage_id):
		_prewarm_stage = stage_id
		_prewarm_complete = bool(PlazaScene.prewarm_assets_threaded_step(stage_id))
	if not _prewarm_complete:
		_last_readiness_rejection_reason = "texture_cache_incomplete"
		return false
	if not BattlePsoPrewarmer.run_hwangyeok_gpu_prewarm_step(owner):
		_last_readiness_rejection_reason = str(BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status().get(
			"last_rejection_reason",
			"gpu_prewarm_incomplete"
		))
		return false
	_last_readiness_rejection_reason = ""
	return true


func was_entry_forced() -> bool:
	return _entry_forced


func advance_entry_readiness(current_stage: int, owner: Object = null) -> bool:
	# Explicit plaza-entry click. The per-frame background step stays
	# nonblocking, but a click must never strand the player on the notice
	# bubble: when the shared threaded pipeline has not converged, drain the
	# remaining texture loads under the same bounded guard ensure_assets_ready()
	# uses and let the plaza's first frame pay any residual GPU upload instead.
	# User-approved 2026-08-12; supersedes the R1 nonblocking-click-only yield.
	if prewarm_assets_step(current_stage, owner):
		_entry_forced = false
		return true
	_print_entry_yield_reason()
	var stage_id: int = maxi(1, current_stage)
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(stage_id)):
		guard += 1
		if guard > 256:
			_last_readiness_rejection_reason = "texture_cache_timeout"
			_print_entry_yield_reason()
			return false
	_prewarm_complete = true
	_prewarm_stage = stage_id
	# Best effort only: the retained flush needs real post-draw frames a click
	# cannot manufacture, so entry proceeds without waiting on it.
	BattlePsoPrewarmer.run_hwangyeok_gpu_prewarm_step(owner)
	_entry_forced = true
	_last_readiness_rejection_reason = ""
	return true


func _print_entry_yield_reason() -> void:
	if _last_readiness_rejection_reason == _printed_entry_yield_reason:
		return
	_printed_entry_yield_reason = _last_readiness_rejection_reason
	print("[PlazaEntry] readiness yield: %s" % _last_readiness_rejection_reason)


func ensure_assets_ready(current_stage: int, owner: Object = null) -> bool:
	var stage_id: int = maxi(1, current_stage)
	if not (_prewarm_complete and _prewarm_stage == stage_id):
		_prewarm_stage = stage_id
		var guard := 0
		while not bool(PlazaScene.prewarm_assets_blocking_step(stage_id)):
			guard += 1
			if guard > 256:
				push_warning("Timed out while prewarming plaza assets for stage %d" % stage_id)
				_last_readiness_rejection_reason = "texture_cache_timeout"
				return false
		_prewarm_complete = true
	if not BattlePsoPrewarmer.run_hwangyeok_gpu_prewarm_step(owner):
		_last_readiness_rejection_reason = str(BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status().get(
			"last_rejection_reason",
			"gpu_prewarm_incomplete"
		))
		return false
	_last_readiness_rejection_reason = ""
	return true
