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
		"ornament_texture": context.get("gauge_orb_ki_jade_ornament_texture", null),
		"frame_spin_angle": context.get("gauge_frame_spin_angle", 0.0),
		"hud_lod_scale": context.get("hud_lod_scale", 1.0),
		"pillar_hud_static_lod": bool(context.get("pillar_hud_static_lod", false)),
	}


func build_dash_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	var dash_snapshot: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	return {
		"pillar_drawer": orb_drawer,
		"frame_width_base": PILLAR_ORB_FRAME_WIDTH_BASE,
		"tokens": dash_snapshot.get("tokens", 0),
		"max_tokens": dash_snapshot.get("max_tokens", 1),
		"charge_timer": dash_snapshot.get("charge_timer", 0.0),
		"recharge_frames": dash_snapshot.get("recharge_frames", 300.0),
		"boost_charging_pending_dash_refund": dash_snapshot.get("boost_charging_pending_dash_refund", false),
		"boost_charging_active": dash_snapshot.get("boost_charging_active", false),
		"boost_charging_timer": dash_snapshot.get("boost_charging_timer", 0.0),
		"boost_charging_token_index": dash_snapshot.get("boost_charging_token_index", -1),
		"flash_timer": context.get("dash_flash_timer", 0.0),
		"flash_duration": context.get("dash_flash_duration", 0.55),
		"dash_divider_anim_progress": context.get("dash_divider_anim_progress", 1.0),
		"dash_available_timer": dash_snapshot.get("available_timer", 0.0),
		"dash_active": dash_snapshot.get("active", false),
		"dash_recovering": dash_snapshot.get("recovering", false),
		"dash_stun_timer": dash_snapshot.get("stun_timer", 0.0),
		"frame_texture": context.get("dash_frame_texture", null),
		"bell_cell_texture": context.get("dash_token_bell_cell_texture", null),
		"frame_spin_angle": context.get("dash_frame_spin_angle", 0.0),
		"hud_lod_scale": context.get("hud_lod_scale", 1.0),
		"pillar_hud_static_lod": bool(context.get("pillar_hud_static_lod", false)),
	}


func build_boss_dash_orb_context(context: Dictionary, orb_drawer: Object) -> Dictionary:
	var dash_snapshot: Dictionary = _get_dict(context.get("boss_dash_snapshot", {}))
	return {
		"pillar_drawer": orb_drawer,
		"frame_width_base": PILLAR_ORB_FRAME_WIDTH_BASE,
		"tokens": dash_snapshot.get("tokens", 1),
		"max_tokens": dash_snapshot.get("max_tokens", 1),
		"charge_timer": dash_snapshot.get("charge_timer", 0.0),
		"recharge_frames": dash_snapshot.get("recharge_frames", 1.0),
		"charge_progress": dash_snapshot.get("charge_progress", 1.0),
		"flash_timer": context.get("boss_dash_flash_timer", 0.0),
		"flash_duration": context.get("boss_dash_flash_duration", 0.55),
		"dash_divider_anim_progress": context.get("boss_dash_divider_anim_progress", 1.0),
		"dash_available_timer": dash_snapshot.get("available_timer", 1.0),
		"dash_active": dash_snapshot.get("active", false),
		"dash_recovering": dash_snapshot.get("recovering", false),
		"dash_stun_timer": dash_snapshot.get("stun_timer", 0.0),
		"frame_texture": context.get("boss_dash_frame_texture", null),
		"bell_cell_texture": context.get("dash_token_bell_cell_texture", null),
		"frame_spin_angle": context.get("boss_dash_frame_spin_angle", 0.0),
		"hud_lod_scale": context.get("hud_lod_scale", 1.0),
		"pillar_hud_static_lod": bool(context.get("pillar_hud_static_lod", false)),
		"compact_fallback_frame": true,
		"show_half_label": false,
		"glass_rim_color": Color(0.86, 0.56, 1.0, 1.0),
		"orb_outer_glow_color": Color(0.62, 0.26, 1.0, 1.0),
		"orb_metal_dark": Color(0.10, 0.06, 0.16, 1.0),
		"orb_metal_mid": Color(0.30, 0.20, 0.44, 1.0),
		"orb_metal_light": Color(0.62, 0.46, 0.78, 1.0),
		"orb_gem_core": Color(0.58, 0.20, 0.88, 1.0),
		"orb_gem_highlight": Color(0.92, 0.76, 1.0, 1.0),
		"orb_background_outer": Color(0.08, 0.04, 0.14, 1.0),
		"orb_background_inner": Color(0.22, 0.11, 0.34, 1.0),
		"orb_particle_color": Color(0.80, 0.50, 1.0, 1.0),
		"orb_particle_core_color": Color(1.0, 0.92, 1.0, 1.0),
		"orb_core_outer_color": Color(0.58, 0.22, 0.88, 1.0),
		"orb_core_inner_color": Color(0.90, 0.48, 1.0, 1.0),
		"token_liquid_top": Color(0.72, 0.34, 1.0, 1.0),
		"token_liquid_bottom": Color(0.20, 0.08, 0.34, 1.0),
		"token_wave_glow": Color(0.92, 0.76, 1.0, 1.0),
		"token_full_color": Color(0.55, 0.20, 0.84, 1.0),
		"token_inner_glow": Color(0.88, 0.64, 1.0, 1.0),
		"idle_ring_color": Color(0.78, 0.42, 1.0, 1.0),
	}


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
