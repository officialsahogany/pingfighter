extends RefCounted

const PILLAR_ORB_FRAME_WIDTH_BASE := 10.0


func build_gauge_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	return {
		"pillar_drawer": orb_drawer,
		"frame_width_base": PILLAR_ORB_FRAME_WIDTH_BASE,
		"gauge_value": context.get("special_gauge", 0.0),
		"gauge_max": context.get("gauge_max", 500.0),
		"flash_timer": context.get("gauge_flash_timer", 0.0),
		"flash_duration": context.get("gauge_flash_duration", 0.45),
		"frame_texture": context.get("gauge_frame_texture", null),
		"frame_spin_angle": context.get("gauge_frame_spin_angle", 0.0),
	}


func build_dash_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	var dash_snapshot: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	return {
		"pillar_drawer": orb_drawer,
		"frame_width_base": PILLAR_ORB_FRAME_WIDTH_BASE,
		"tokens": dash_snapshot.get("tokens", 0),
		"max_tokens": dash_snapshot.get("max_tokens", 1),
		"charge_timer": dash_snapshot.get("charge_timer", 0.0),
		"recharge_frames": dash_snapshot.get("recharge_frames", 90.0),
		"flash_timer": context.get("dash_flash_timer", 0.0),
		"flash_duration": context.get("dash_flash_duration", 0.55),
		"dash_divider_anim_progress": context.get("dash_divider_anim_progress", 1.0),
		"dash_available_timer": dash_snapshot.get("available_timer", 0.0),
		"dash_active": dash_snapshot.get("active", false),
		"frame_texture": context.get("dash_frame_texture", null),
		"frame_spin_angle": context.get("dash_frame_spin_angle", 0.0),
	}


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
