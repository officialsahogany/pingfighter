extends RefCounted


static func build_confirm_intro_config(character: Dictionary) -> Dictionary:
	var sheet_path := str(character.get("confirm_intro_sheet_path", ""))
	if sheet_path == "":
		return {}
	return {
		"path": sheet_path,
		"cols": int(character.get("confirm_intro_cols", 1)),
		"rows": int(character.get("confirm_intro_rows", 1)),
		"count": int(character.get("confirm_intro_count", 1)),
		"interval": float(character.get("confirm_intro_interval", 0.033)),
		"min_interval": float(character.get("confirm_intro_min_interval", 0.016)),
		"min_duration": float(character.get("confirm_intro_min_duration", 0.0)),
		"trim_transparent_source": bool(character.get("confirm_intro_trim_transparent_source", false)),
		"trim_rect": character.get("confirm_intro_trim_rect", Rect2()),
		"float_motion_enabled": bool(character.get("confirm_intro_float_motion_enabled", false)),
		"align_bottom_to_cutline": bool(character.get("confirm_intro_align_bottom_to_cutline", false)),
		"transition_duration": float(character.get("confirm_intro_transition_duration", 0.0)),
		"return_transition_duration": float(character.get("confirm_intro_return_transition_duration", character.get("confirm_intro_transition_duration", 0.0))),
		"restore_elapsed_mode": str(character.get("confirm_intro_restore_elapsed_mode", "continue")),
		"stage_scale": float(character.get("confirm_intro_stage_scale", 1.0)),
		"stage_x_offset_ratio": float(character.get("confirm_intro_stage_x_offset_ratio", 0.0)),
		"stage_y_offset_ratio": float(character.get("confirm_intro_stage_y_offset_ratio", 0.0)),
		"restore_after_finish": false,
	}


static func build_preview_click_motion_config(character: Dictionary) -> Dictionary:
	var sheet_path := str(character.get("click_motion_sheet_path", ""))
	if sheet_path != "":
		return {
			"path": sheet_path,
			"cols": int(character.get("click_motion_cols", character.get("confirm_intro_cols", 1))),
			"rows": int(character.get("click_motion_rows", character.get("confirm_intro_rows", 1))),
			"count": int(character.get("click_motion_count", character.get("confirm_intro_count", 1))),
			"interval": float(character.get("click_motion_interval", character.get("confirm_intro_interval", 0.033))),
			"min_interval": float(character.get("click_motion_min_interval", character.get("confirm_intro_min_interval", 0.016))),
			"min_duration": float(character.get("click_motion_min_duration", character.get("confirm_intro_min_duration", 0.0))),
			"trim_transparent_source": bool(character.get("click_motion_trim_transparent_source", character.get("confirm_intro_trim_transparent_source", false))),
			"trim_rect": character.get("click_motion_trim_rect", character.get("confirm_intro_trim_rect", Rect2())),
			"float_motion_enabled": bool(character.get("click_motion_float_motion_enabled", character.get("confirm_intro_float_motion_enabled", false))),
			"align_bottom_to_cutline": bool(character.get("click_motion_align_bottom_to_cutline", character.get("confirm_intro_align_bottom_to_cutline", false))),
			"transition_duration": float(character.get("click_motion_transition_duration", character.get("confirm_intro_transition_duration", 0.0))),
			"return_transition_duration": float(character.get("click_motion_return_transition_duration", character.get("confirm_intro_return_transition_duration", 0.18))),
			"restore_elapsed_mode": str(character.get("click_motion_restore_elapsed_mode", character.get("confirm_intro_restore_elapsed_mode", "continue"))),
			"stage_scale": float(character.get("click_motion_stage_scale", character.get("confirm_intro_stage_scale", 1.0))),
			"stage_x_offset_ratio": float(character.get("click_motion_stage_x_offset_ratio", character.get("confirm_intro_stage_x_offset_ratio", 0.0))),
			"stage_y_offset_ratio": float(character.get("click_motion_stage_y_offset_ratio", character.get("confirm_intro_stage_y_offset_ratio", 0.0))),
			"return_sheet_path": str(character.get("click_motion_return_sheet_path", character.get("confirm_intro_return_sheet_path", ""))),
			"return_cols": int(character.get("click_motion_return_cols", character.get("confirm_intro_return_cols", 1))),
			"return_rows": int(character.get("click_motion_return_rows", character.get("confirm_intro_return_rows", 1))),
			"return_count": int(character.get("click_motion_return_count", character.get("confirm_intro_return_count", 1))),
			"return_interval": float(character.get("click_motion_return_interval", character.get("confirm_intro_return_interval", 0.033))),
			"return_min_interval": float(character.get("click_motion_return_min_interval", character.get("confirm_intro_return_min_interval", 0.016))),
			"return_min_duration": float(character.get("click_motion_return_min_duration", character.get("confirm_intro_return_min_duration", 0.0))),
			"return_trim_transparent_source": bool(character.get("click_motion_return_trim_transparent_source", character.get("confirm_intro_return_trim_transparent_source", false))),
			"return_trim_rect": character.get("click_motion_return_trim_rect", character.get("confirm_intro_return_trim_rect", Rect2())),
			"return_float_motion_enabled": bool(character.get("click_motion_return_float_motion_enabled", character.get("confirm_intro_return_float_motion_enabled", false))),
			"return_align_bottom_to_cutline": bool(character.get("click_motion_return_align_bottom_to_cutline", character.get("confirm_intro_return_align_bottom_to_cutline", character.get("click_motion_align_bottom_to_cutline", character.get("confirm_intro_align_bottom_to_cutline", false))))),
			"return_stage_scale": float(character.get("click_motion_return_stage_scale", character.get("confirm_intro_return_stage_scale", character.get("click_motion_stage_scale", character.get("confirm_intro_stage_scale", 1.0))))),
			"return_stage_x_offset_ratio": float(character.get("click_motion_return_stage_x_offset_ratio", character.get("confirm_intro_return_stage_x_offset_ratio", character.get("click_motion_stage_x_offset_ratio", character.get("confirm_intro_stage_x_offset_ratio", 0.0))))),
			"return_stage_y_offset_ratio": float(character.get("click_motion_return_stage_y_offset_ratio", character.get("confirm_intro_return_stage_y_offset_ratio", character.get("click_motion_stage_y_offset_ratio", character.get("confirm_intro_stage_y_offset_ratio", 0.0))))),
			"restore_after_finish": true,
		}
	var confirm_path := str(character.get("confirm_intro_sheet_path", ""))
	if confirm_path != "":
		return _build_confirm_intro_preview_fallback(character, confirm_path)
	var still_path := str(character.get("live2d_preview_still_path", character.get("portrait_path", "")))
	if still_path == "":
		return {}
	return {
		"path": still_path,
		"cols": 1,
		"rows": 1,
		"count": 1,
		"interval": 0.016,
		"return_transition_duration": 0.18,
		"restore_after_finish": true,
	}


static func _build_confirm_intro_preview_fallback(character: Dictionary, confirm_path: String) -> Dictionary:
	return {
		"path": confirm_path,
		"cols": int(character.get("confirm_intro_cols", 1)),
		"rows": int(character.get("confirm_intro_rows", 1)),
		"count": int(character.get("confirm_intro_count", 1)),
		"interval": float(character.get("confirm_intro_interval", 0.033)),
		"min_interval": float(character.get("confirm_intro_min_interval", 0.016)),
		"min_duration": float(character.get("confirm_intro_min_duration", 0.0)),
		"trim_transparent_source": bool(character.get("confirm_intro_trim_transparent_source", false)),
		"trim_rect": character.get("confirm_intro_trim_rect", Rect2()),
		"float_motion_enabled": bool(character.get("confirm_intro_float_motion_enabled", false)),
		"align_bottom_to_cutline": bool(character.get("confirm_intro_align_bottom_to_cutline", false)),
		"transition_duration": float(character.get("confirm_intro_transition_duration", 0.0)),
		"return_transition_duration": float(character.get("confirm_intro_return_transition_duration", 0.18)),
		"restore_elapsed_mode": str(character.get("confirm_intro_restore_elapsed_mode", "continue")),
		"stage_scale": float(character.get("confirm_intro_stage_scale", 1.0)),
		"stage_x_offset_ratio": float(character.get("confirm_intro_stage_x_offset_ratio", 0.0)),
		"stage_y_offset_ratio": float(character.get("confirm_intro_stage_y_offset_ratio", 0.0)),
		"return_sheet_path": str(character.get("confirm_intro_return_sheet_path", "")),
		"return_cols": int(character.get("confirm_intro_return_cols", 1)),
		"return_rows": int(character.get("confirm_intro_return_rows", 1)),
		"return_count": int(character.get("confirm_intro_return_count", 1)),
		"return_interval": float(character.get("confirm_intro_return_interval", 0.033)),
		"return_min_interval": float(character.get("confirm_intro_return_min_interval", 0.016)),
		"return_min_duration": float(character.get("confirm_intro_return_min_duration", 0.0)),
		"return_trim_transparent_source": bool(character.get("confirm_intro_return_trim_transparent_source", false)),
		"return_trim_rect": character.get("confirm_intro_return_trim_rect", Rect2()),
		"return_float_motion_enabled": bool(character.get("confirm_intro_return_float_motion_enabled", false)),
		"return_align_bottom_to_cutline": bool(character.get("confirm_intro_return_align_bottom_to_cutline", character.get("confirm_intro_align_bottom_to_cutline", false))),
		"return_stage_scale": float(character.get("confirm_intro_return_stage_scale", character.get("confirm_intro_stage_scale", 1.0))),
		"return_stage_x_offset_ratio": float(character.get("confirm_intro_return_stage_x_offset_ratio", character.get("confirm_intro_stage_x_offset_ratio", 0.0))),
		"return_stage_y_offset_ratio": float(character.get("confirm_intro_return_stage_y_offset_ratio", character.get("confirm_intro_stage_y_offset_ratio", 0.0))),
		"restore_after_finish": true,
	}
