extends RefCounted

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")


static func open(target: Object, owner: Object = null, registry: Object = null, pause_active: bool = false, pause_owner: Object = null, pause_registry: Object = null) -> Dictionary:
	target.set("active", true)
	target.set("animation_time", 0.0)
	target.set("lingpet_panel_live2d_time", 0.0)
	target.set("_lingpet_panel_live2d_redraw_active", false)
	target.set("perk_scroll", 0.0)
	target.set("passive_inventory_scroll", 0.0)
	var pendulum: Object = target.get("_pendulum_interior")
	if pendulum != null and pendulum.has_method("reset"):
		pendulum.reset()
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


static func close(target: Object, from_input: bool = false, pause_active: bool = false, pause_owner: Object = null, pause_registry: Object = null) -> Dictionary:
	if pause_active:
		var skill_tooltip_driver: Object = CharacterInfoOverlayOwnerState.get_instance(pause_registry, "battle_scene_skill_tooltip_driver")
		if skill_tooltip_driver != null and skill_tooltip_driver.has_method("resume_skill_cooldowns"):
			skill_tooltip_driver.resume_skill_cooldowns(pause_owner, pause_registry)
	target.set("active", false)
	target.set("_lingpet_panel_live2d_redraw_active", false)
	var pendulum: Object = target.get("_pendulum_interior")
	if pendulum != null and pendulum.has_method("reset"):
		pendulum.reset()
	target.call("_reset_hover_and_request_redraw", from_input)
	return {
		"active": false,
		"owner": null,
		"registry": null,
	}


static func update(target: Object, delta: float, open_animation_duration: float) -> bool:
	if not bool(target.get("active")):
		return false
	var live2d_redraw_active: bool = bool(target.get("_lingpet_panel_live2d_redraw_active"))
	if live2d_redraw_active:
		target.set("lingpet_panel_live2d_time", float(target.get("lingpet_panel_live2d_time")) + delta)
	var pendulum: Object = target.get("_pendulum_interior")
	var pendulum_active := false
	if pendulum != null and pendulum.has_method("is_active"):
		pendulum_active = bool(pendulum.is_active())
		if pendulum_active and pendulum.has_method("advance"):
			pendulum.advance(delta)
	var animation_time: float = float(target.get("animation_time"))
	var was_animating: bool = animation_time < open_animation_duration
	var next_animation_time: float = min(open_animation_duration, animation_time + delta)
	target.set("animation_time", next_animation_time)
	if was_animating:
		if next_animation_time >= open_animation_duration:
			target.set("_redraw_requested", false)
		return true
	var should_redraw: bool = bool(target.get("_redraw_requested"))
	target.set("_redraw_requested", false)
	return should_redraw or live2d_redraw_active or pendulum_active
