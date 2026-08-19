extends RefCounted

# Read-only Stage 7 snapshot of Odin's Eye boss crowd-control state.
#
# Resolution is deliberately non-instantiating: direct smoke/runtime injection
# wins, then an already-provided mythic runtime, then one registry cache peek.

var knockback_window_active := false
var knockback_vel := 0.0
var stun_residual := 0.0


func reset_full() -> void:
	clear_snapshot()


func clear_snapshot() -> void:
	knockback_window_active = false
	knockback_vel = 0.0
	stun_residual = 0.0


func sync_from_deps(deps: Dictionary) -> void:
	clear_snapshot()
	var swamp: Object = deps.get("odins_eye_dark_swamp_state", null)
	if swamp == null:
		var mythic: Object = deps.get("mythic_item_runtime", null)
		if mythic != null:
			var swamp_value: Variant = mythic.get("odins_eye_dark_swamp_state")
			if swamp_value is Object:
				swamp = swamp_value
	if swamp == null:
		var registry: Object = deps.get("registry", null)
		if registry != null and registry.has_method("get_cached_instance"):
			var mythic_peek: Object = registry.get_cached_instance("mythic_item_runtime")
			if mythic_peek != null:
				var swamp_peek: Variant = mythic_peek.get("odins_eye_dark_swamp_state")
				if swamp_peek is Object:
					swamp = swamp_peek
	if swamp == null:
		return
	knockback_window_active = float(swamp.get("boss_knockback_timer_frames")) > 0.0
	if knockback_window_active:
		knockback_vel = float(swamp.get("boss_knockback_vel"))
	if float(swamp.get("boss_stun_timer_frames")) > 0.0:
		stun_residual = float(swamp.get("boss_knockback_vel"))


func get_escape_rewind_x() -> float:
	return knockback_vel if knockback_window_active else 0.0


func get_snapshot() -> Dictionary:
	return {
		"knockback_window_active": knockback_window_active,
		"knockback_vel": knockback_vel,
		"stun_residual": stun_residual,
	}
