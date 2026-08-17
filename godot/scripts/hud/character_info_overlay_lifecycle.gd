extends RefCounted

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const LINGPET_PANEL_ANIM_STEP_MSEC := 63

static func open(target: Object, owner: Object = null, registry: Object = null, pause_active: bool = false, pause_owner: Object = null, pause_registry: Object = null) -> Dictionary:
	target.set("active", true)
	target.set("animation_time", 0.0)
	target.set("_closing", false)
	target.set("_closing_start_animation_time", 0.0)
	target.set("_closing_deadline_msec", 0)
	target.set("_opening_input_locked", true)
	target.set("lingpet_panel_live2d_time", 0.0)
	target.set("_lingpet_panel_live2d_redraw_active", false)
	target.set("_lingpet_panel_anim_frame_step", -1)
	target.set("perk_scroll", 0.0)
	target.set("passive_inventory_scroll", 0.0)
	var next_pause_active := pause_active
	var next_pause_owner: Object = pause_owner
	var next_pause_registry: Object = pause_registry
	if not next_pause_active and owner != null and registry != null:
		var skill_tooltip_driver: Object = CharacterInfoOverlayOwnerState.get_instance(registry, "battle_scene_skill_tooltip_driver")
		if skill_tooltip_driver != null and skill_tooltip_driver.has_method("pause_skill_cooldowns"):
			skill_tooltip_driver.pause_skill_cooldowns(owner, registry)
			next_pause_active = true
			next_pause_owner = owner
			next_pause_registry = registry
	target.call("_reset_hover_and_request_redraw")
	return {
		"active": next_pause_active,
		"owner": next_pause_owner,
		"registry": next_pause_registry,
	}


static func close(target: Object, from_input: bool = false, pause_active: bool = false, pause_owner: Object = null, pause_registry: Object = null, close_animation_duration: float = 0.0) -> Dictionary:
	# Player TAB/ESC closes reverse the opening projection. Keep the modal and
	# cooldown pause alive until update() reaches the fully folded frame.
	# System cleanup calls retain the historical immediate-close contract.
	if from_input and bool(target.get("active")):
		if not bool(target.get("_closing")):
			target.set("_closing", true)
			target.set("_closing_start_animation_time", float(target.get("animation_time")))
			# The ordinary controller update owns the visible reverse-fold. Keep an
			# absolute deadline as a fail-safe: another higher-priority idle lane must
			# never strand this modal at a tiny final frame with gameplay still paused.
			var close_timeout_msec := maxi(1, int(ceil(maxf(0.0, close_animation_duration) * 1000.0)))
			target.set("_closing_deadline_msec", Time.get_ticks_msec() + close_timeout_msec)
			target.set("_opening_input_locked", true)
			target.set("_lingpet_panel_live2d_redraw_active", false)
			target.call("_reset_hover_and_request_redraw", true)
		return {
			"active": pause_active,
			"owner": pause_owner,
			"registry": pause_registry,
		}
	if pause_active:
		var skill_tooltip_driver: Object = CharacterInfoOverlayOwnerState.get_instance(pause_registry, "battle_scene_skill_tooltip_driver")
		if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
			skill_tooltip_driver.resume_skill_cooldowns(pause_owner, pause_registry)
	target.set("active", false)
	target.set("animation_time", 0.0)
	target.set("_closing", false)
	target.set("_closing_start_animation_time", 0.0)
	target.set("_closing_deadline_msec", 0)
	target.set("_opening_input_locked", false)
	target.set("_lingpet_panel_live2d_redraw_active", false)
	target.set("_lingpet_panel_anim_frame_step", -1)
	target.call("_reset_hover_and_request_redraw", from_input)
	return {
		"active": false,
		"owner": null,
		"registry": null,
	}


static func update(target: Object, delta: float, open_animation_duration: float, close_animation_duration: float) -> bool:
	if complete_expired_close(target):
		return true
	if not bool(target.get("active")):
		return false
	if bool(target.get("_closing")):
		var close_speed := open_animation_duration / maxf(0.001, close_animation_duration)
		var next_close_time := maxf(0.0, float(target.get("animation_time")) - delta * close_speed)
		target.set("animation_time", next_close_time)
		if next_close_time <= 0.0:
			target.call("_complete_deferred_close")
		return true
		# Closing owns the phase clock exclusively. Falling through to the opening
		# branch below would add `delta` back and leave the modal pause alive after
		# a settled TAB panel starts folding.
		return true
	var live2d_redraw_active: bool = bool(target.get("_lingpet_panel_live2d_redraw_active"))
	var live2d_redraw := false
	if live2d_redraw_active:
		target.set("lingpet_panel_live2d_time", float(target.get("lingpet_panel_live2d_time")) + delta)
		live2d_redraw = _consume_lingpet_panel_redraw(target)
	var animation_time: float = float(target.get("animation_time"))
	var was_animating: bool = animation_time < open_animation_duration
	var next_animation_time: float = min(open_animation_duration, animation_time + delta)
	target.set("animation_time", next_animation_time)
	if was_animating:
		if next_animation_time >= open_animation_duration:
			target.set("_opening_input_locked", false)
			target.set("_redraw_requested", false)
		return true
	var should_redraw: bool = bool(target.get("_redraw_requested"))
	target.set("_redraw_requested", false)
	var animated_perk_redraw: bool = _consume_animated_perk_redraw(target)
	return should_redraw or live2d_redraw or animated_perk_redraw


# `is_active()` is queried by both the process-overlay scan and the physics
# modal gate, even when some other controller owns the current idle frame. That
# makes this deadline check the final authority that releases gameplay if the
# normal close update is temporarily starved.
static func complete_expired_close(target: Object) -> bool:
	if not bool(target.get("active")) or not bool(target.get("_closing")):
		return false
	var deadline_msec := int(target.get("_closing_deadline_msec"))
	if deadline_msec <= 0 or Time.get_ticks_msec() < deadline_msec:
		return false
	target.call("_complete_deferred_close")
	return true


# The panel animation uses a 16 FPS sheet. Keep its clock advancing at the
# controller cadence, but redraw the expensive full TAB overlay only when the
# visible animation frame can actually change.
static func _consume_lingpet_panel_redraw(target: Object) -> bool:
	var step: int = int(Time.get_ticks_msec() / LINGPET_PANEL_ANIM_STEP_MSEC)
	if step == int(target.get("_lingpet_panel_anim_frame_step")):
		return false
	target.set("_lingpet_panel_anim_frame_step", step)
	return true


# Throttled redraw request that keeps sheet-backed perk icons playing in the TAB panel
# without a mouse-move nudge. The grid supplies the fastest visible sheet interval, so
# an all-peerless grid redraws at the AutoSprite 250ms cadence while mixed/faster sheets
# still advance correctly. An all-static panel keeps zero redraw cost.
static func _consume_animated_perk_redraw(target: Object) -> bool:
	if not bool(target.get("_perk_grid_has_animated_icon")):
		return false
	var step_msec := maxi(1, int(target.get("_perk_grid_anim_step_msec")))
	var step: int = int(Time.get_ticks_msec() / step_msec)
	if step == int(target.get("_perk_grid_anim_frame_step")):
		return false
	target.set("_perk_grid_anim_frame_step", step)
	return true
