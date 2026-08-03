extends RefCounted

# 백린 (baekrin) active skill — 묵린변신 / Mokrin Transform.
#
# P0 contract (docs/lingpet_baekrin_mokrin_slice_plan.md D5~D15, 확정 2026-07-31):
# a 5-second window in which the PLAYER PADDLE is auto-piloted with the exact
# AIPill (신령환) guard-tracking calculation. NO ball-speed bonus, NO projectile,
# NO summon, NO boss CC, NO companion position scripting — the transform is
# presentation-only plus the paddle autopilot.
#
# Ownership split (D15 / registration matrix):
# - This module owns ONLY the transform window state (active + elapsed timer).
# - The actual paddle movement is owned by smasher_player_controller, which reads
#   the state through the narrow D15 bridge (egg runtime predicate -> fail-closed
#   Callable in the player-control deps) and REUSES active_item_aipill_behavior's
#   apply_player_control() math verbatim. This module must never touch player_pos.
# - Cooldown (40s) is owned by companion_skill_persistence via the launch path
#   (complete_launch cooldown_seconds from catalog data) — not by this module.
# - The transform DISPLAY (companion_puppet_control sheet, D5a grid meta, D5c
#   y-offset delta, ink flash palette) is S1b render wiring; this module only
#   exposes the progress scalar the surface router will consume.
# - Guard counting / stage SFX (E' X1~X4) land with the S1b notify wiring; no
#   guard surface exists here yet on purpose (no producer -> no surface).
#
# Reset boundaries (D14): natural expiry ticks down here; round reset / stow /
# pet swap arrive through the host fanout (reset_round -> cancel -> reset, and
# end_for_stow -> reset). Cooldown is NOT refunded on any of them because it
# lives in companion_skill_persistence, untouched by this module.

const TRANSFORM_DURATION_SECONDS := 5.0
# ㉮ (rev7): the transform sheet plays 0 -> 1 over 0.60s, then holds f12.
const TRANSFORM_PROGRESS_SECONDS := 0.60
# ㉯ (rev8): guard stage = min(guard_count, 3); each stage fires its entry SFX
# exactly once (the confirmed cue is the shared play_active_item — no new audio
# source, zero game_audio.gd contact).
const GUARD_STAGE_MAX := 3

var _active := false
var _elapsed := 0.0
var _duration_seconds := TRANSFORM_DURATION_SECONDS
var _guard_count := 0
var _last_guard_stage_fired := 0


func prewarm() -> void:
	# C5: the transform sheet / card prewarm joins the S1b catalog wiring; the
	# S1a module has no assets of its own to warm.
	pass


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_duration_seconds = TRANSFORM_DURATION_SECONDS
	_guard_count = 0
	_last_guard_stage_fired = 0


func cancel(_owner: Object = null, _registry: Object = null) -> void:
	reset()


func launch(_origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	# C2 backing: while the window is live a relaunch must fail (the host's
	# is_launch_blocked arm also gates earlier, at _should_arm).
	if _active:
		return false
	var supplied_duration := float(launch_context.get("transform_duration", 0.0))
	_duration_seconds = supplied_duration if supplied_duration > 0.0 else TRANSFORM_DURATION_SECONDS
	_elapsed = 0.0
	_active = true
	return true


func update(delta: float, _owner: Object, _registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if not _active:
		return
	_elapsed += maxf(0.0, delta)
	if _elapsed >= _duration_seconds:
		# Natural expiry (D14 boundary #1). The next player-control frame simply
		# stops seeing the predicate — no teardown beyond this state flip exists.
		reset()


func is_active() -> bool:
	# C4 liveness: needs_runtime_update_for_skill()'s generic is_active() probe
	# keeps this module ticking through frames with zero visible effects.
	return _active


func is_transform_active() -> bool:
	# D15 bridge peek target (host -> egg runtime -> player-control Callable).
	return _active


func has_visible_effects() -> bool:
	# S1a: this module draws nothing (D1~D3 N/A — the body swap is renderer-owned
	# S1b work). Liveness while invisible is exactly what is_active() covers.
	return false


func get_transform_progress() -> float:
	# D5 consumer (S1b surface router): 0..1 over the first 0.60s, then held at 1.
	if not _active:
		return 0.0
	return clampf(_elapsed / TRANSFORM_PROGRESS_SECONDS, 0.0, 1.0)


func get_companion_cast_pose_progress() -> float:
	# D5 duck-typed surface consumed by the companion surface router: -1 while
	# inactive (cast pose off -> normal body), else the held 0..1 sheet progress.
	if not _active:
		return -1.0
	return get_transform_progress()


func notify_player_guard(registry: Object = null) -> void:
	# E' X1: called from the paddle-bounce event router (BEFORE the AIPill early
	# return, base-paddle hits only — thor shield / dual-glitch clone bounces are
	# filtered at the call site, X3). Counts a guard and fires each stage's entry
	# SFX exactly once (㉯: stages 1/2/3, no re-fire at the same count).
	if not _active:
		return
	_guard_count += 1
	var stage: int = mini(_guard_count, GUARD_STAGE_MAX)
	if stage <= _last_guard_stage_fired:
		return
	_last_guard_stage_fired = stage
	_play_guard_stage_sfx(registry)


func get_guard_count() -> int:
	return _guard_count


func get_guard_stage() -> int:
	if not _active:
		return 0
	return mini(_guard_count, GUARD_STAGE_MAX)


func _play_guard_stage_sfx(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance("game_audio")
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			audio = cached as Object
	if audio == null and registry.has_method("get_instance"):
		var value: Variant = registry.get_instance("game_audio")
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			audio = value as Object
	if audio != null and audio.has_method("play_active_item"):
		audio.play_active_item()


func get_remaining_seconds() -> float:
	if not _active:
		return 0.0
	return maxf(0.0, _duration_seconds - _elapsed)


func get_snapshot() -> Dictionary:
	return {
		"mokrin_transform_active": _active,
		"mokrin_transform_progress": get_transform_progress(),
		"mokrin_transform_remaining_seconds": get_remaining_seconds(),
		"mokrin_transform_guard_count": _guard_count,
		"mokrin_transform_guard_stage": get_guard_stage(),
	}
