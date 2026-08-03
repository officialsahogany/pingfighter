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

var _active := false
var _elapsed := 0.0
var _duration_seconds := TRANSFORM_DURATION_SECONDS


func prewarm() -> void:
	# C5: the transform sheet / card prewarm joins the S1b catalog wiring; the
	# S1a module has no assets of its own to warm.
	pass


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_duration_seconds = TRANSFORM_DURATION_SECONDS


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


func get_remaining_seconds() -> float:
	if not _active:
		return 0.0
	return maxf(0.0, _duration_seconds - _elapsed)


func get_snapshot() -> Dictionary:
	return {
		"mokrin_transform_active": _active,
		"mokrin_transform_progress": get_transform_progress(),
		"mokrin_transform_remaining_seconds": get_remaining_seconds(),
	}
