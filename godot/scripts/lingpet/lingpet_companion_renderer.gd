extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

# Soft ambient aura tuning. The persistent companion glow (Lunabi / Maribo) is a
# cached radial-falloff texture blitted as a few fully-overlapping low-alpha
# layers -- NOT a hard draw_circle disc, and NOT discrete orbiting dots (those
# read as "air bubbles") -- so the SD body reads as wrapped in one smooth, even
# fluorescent glow. Kept deliberately faint and feathered ("아주 티 안 나게 투명"),
# driven by a two-rate organic breathing ease. The flash/burst glows below stay
# sharp on purpose -- those are gameplay feedback, not the ambient aura.
const _SOFT_GLOW_TEX_SIZE := 64


func prewarm_assets() -> void:
	_get_or_create_soft_glow_texture()


func draw_companion(canvas: CanvasItem, center: Vector2, config: Dictionary) -> void:
	if canvas == null:
		return
	if not bool(config.get("companion_visible", true)):
		return
	var radius: float = float(config.get("radius", 16.0))
	var hit_flash: float = float(config.get("hit_flash", 0.0))
	var gauge_flash: float = float(config.get("gauge_flash", 0.0))
	var skill_flash: float = float(config.get("skill_flash", 0.0))
	var switch_transition: float = clampf(float(config.get("switch_transition", 0.0)), 0.0, 1.0)
	# Ghost (free_flight) fade: rabi fades out before vanishing and fades in on
	# reappear. 1.0 for non-ghost pets. Applied to the aura + sprite so the whole
	# companion fades coherently instead of hard-popping.
	var ghost_alpha: float = clampf(float(config.get("companion_alpha", 1.0)), 0.0, 1.0)
	var now_ms: float = float(Time.get_ticks_msec())
	var bob: float = sin(now_ms * 0.0048) * 2.6
	var draw_center: Vector2 = center + Vector2(0.0, bob)
	var guard_aura_ratio: float = clampf(float(config.get("defense_guard_aura_ratio", 0.0)), 0.0, 1.0)
	# Soft "barely-there" ambient aura -- replaces the old hard draw_circle disc.
	# See the _SOFT_GLOW_TEX_SIZE notes at the top of the file.
	_draw_soft_aura(canvas, draw_center, radius, now_ms, ghost_alpha, false, guard_aura_ratio)
	if switch_transition > 0.0:
		_draw_switch_transition(canvas, draw_center, radius, switch_transition, int(config.get("switch_particles", 12)), int(config.get("switch_trigger_count", 0)))
	var sprite_alpha: float = (1.0 if switch_transition <= 0.0 else lerpf(0.42, 1.0, 1.0 - switch_transition)) * ghost_alpha
	_draw_companion_sprite(canvas, draw_center, config, sprite_alpha)
	if switch_transition > 0.0:
		_draw_switch_label(canvas, draw_center, str(config.get("display_name", "")), switch_transition)
	if gauge_flash > 0.0:
		var gauge_radius: float = lerpf(radius + 14.0, radius + 42.0, 1.0 - gauge_flash)
		canvas.draw_circle(draw_center, gauge_radius, Color(1.0, 0.88, 0.24, 0.16 * gauge_flash))
		canvas.draw_arc(draw_center, gauge_radius * 0.82, 0.0, TAU, 36, Color(1.0, 0.94, 0.42, 0.68 * gauge_flash), 2.2, true)
		_draw_burst(canvas, draw_center, gauge_flash, int(config.get("burst_particles", 8)), int(config.get("gauge_trigger_count", 0)), Color(1.0, 0.88, 0.24, 1.0), true)
	if skill_flash > 0.0:
		var skill_radius: float = lerpf(radius + 18.0, radius + 54.0, 1.0 - skill_flash)
		var flash_palette: Dictionary = resolve_skill_flash_palette(str(config.get("companion_skill_flash_style", "")))
		var flash_fill: Color = flash_palette.get("fill", Color(0.24, 0.92, 1.0))
		var flash_arc: Color = flash_palette.get("arc", Color(0.72, 1.0, 1.0))
		var flash_burst: Color = flash_palette.get("burst", Color(0.54, 1.0, 1.0))
		canvas.draw_circle(draw_center, skill_radius, Color(flash_fill.r, flash_fill.g, flash_fill.b, 0.18 * skill_flash))
		canvas.draw_arc(draw_center, skill_radius * 0.82, 0.0, TAU, 40, Color(flash_arc.r, flash_arc.g, flash_arc.b, 0.72 * skill_flash), 2.6, true)
		_draw_burst(canvas, draw_center, skill_flash, int(config.get("burst_particles", 8)), int(config.get("skill_trigger_count", 0)), Color(flash_burst.r, flash_burst.g, flash_burst.b, 1.0), false)
	if hit_flash > 0.0:
		var flash_radius: float = lerpf(radius + 8.0, radius + 34.0, 1.0 - hit_flash)
		canvas.draw_circle(draw_center, flash_radius, Color(0.70, 1.0, 0.92, 0.22 * hit_flash))
		canvas.draw_arc(draw_center, flash_radius * 0.86, 0.0, TAU, 36, Color(0.88, 1.0, 0.76, 0.58 * hit_flash), 2.0, true)


func draw_guard_feedback(canvas: CanvasItem, center: Vector2, config: Dictionary) -> void:
	if canvas == null:
		return
	_draw_guard_label(canvas, config.get("guardian_guard_label", {}), _get_vector2(config.get("shake_offset", Vector2.ZERO), Vector2.ZERO))


func _draw_soft_aura(canvas: CanvasItem, center: Vector2, radius: float, now_ms: float, alpha_mult: float = 1.0, heart_tint: bool = false, guard_aura_ratio: float = 0.0) -> void:
	var tex: Texture2D = _get_or_create_soft_glow_texture()
	if tex == null:
		return
	if alpha_mult <= 0.0:
		return
	# Two-rate breathing: a slow primary swell mixed with a gentler faster
	# shimmer so the pulse never reads as one mechanical sine. Small amplitude.
	var breath_slow: float = 0.5 + 0.5 * sin(now_ms * 0.00082)
	var breath_fast: float = 0.5 + 0.5 * sin(now_ms * 0.0021 + 1.3)
	var breath: float = lerpf(breath_slow, breath_fast, 0.32)
	# The companion sprite renders at ~82 px (WALK_DRAW_SIZE), far larger than the
	# 16 px gameplay hit radius, so the glow must be sized off the VISIBLE body
	# extent (body_r) -- sizing it off `radius` blooms the whole halo behind the
	# sprite and reads as nothing. Three concentric, fully overlapping layers form
	# ONE smooth fluorescent halo (no discrete dots / bubbles): a wide faint rim,
	# a mid body, and a slightly whiter core, brightest hugging the body and
	# fading out well past its silhouette.
	var body_r: float = radius + 14.0
	var core_r: float = body_r + lerpf(13.0, 17.0, breath)
	var core_a: float = lerpf(0.17, 0.22, breath)
	var mid_r: float = body_r + lerpf(24.0, 30.0, breath)
	var mid_a: float = lerpf(0.115, 0.150, breath)
	var outer_r: float = body_r + lerpf(37.0, 45.0, breath)
	var outer_a: float = lerpf(0.060, 0.085, breath)
	var guard_ratio := clampf(guard_aura_ratio, 0.0, 1.0)
	var outer_color := _resolve_aura_color(
		Color(1.0, 0.24, 0.54, outer_a * alpha_mult) if heart_tint else Color(0.20, 1.0, 0.72, outer_a * alpha_mult),
		Color(1.0, 0.20, 0.06, outer_a * alpha_mult),
		guard_ratio
	)
	var mid_color := _resolve_aura_color(
		Color(1.0, 0.38, 0.70, mid_a * alpha_mult) if heart_tint else Color(0.34, 1.0, 0.80, mid_a * alpha_mult),
		Color(1.0, 0.34, 0.12, mid_a * alpha_mult),
		guard_ratio
	)
	var core_color := _resolve_aura_color(
		Color(1.0, 0.72, 0.90, core_a * alpha_mult) if heart_tint else Color(0.66, 1.0, 0.92, core_a * alpha_mult),
		Color(1.0, 0.72, 0.44, core_a * alpha_mult),
		guard_ratio
	)
	_blit_soft_glow(canvas, tex, center, outer_r, outer_color)
	_blit_soft_glow(canvas, tex, center, mid_r, mid_color)
	_blit_soft_glow(canvas, tex, center, core_r, core_color)


func _blit_soft_glow(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)


func _resolve_aura_color(base: Color, guard: Color, guard_ratio: float) -> Color:
	if guard_ratio <= 0.0:
		return base
	if guard_ratio >= 1.0:
		return guard
	return base.lerp(guard, guard_ratio)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


# Cached soft radial-falloff glow sprite, shared with player_state_glow_renderer
# through the common SoftGlowTexture util (cos^2 feathered alpha, project halo
# convention). One-time small CPU build, cached by size off the per-frame hot
# path. cos^2 stays gentle at the rim but keeps real alpha through the mid-radius
# so the glow has visible substance OUTSIDE the sprite silhouette.
static func _get_or_create_soft_glow_texture() -> Texture2D:
	return SoftGlowTexture.get_texture(_SOFT_GLOW_TEX_SIZE)


func _draw_companion_sprite(canvas: CanvasItem, center: Vector2, config: Dictionary, alpha: float = 1.0) -> void:
	var animator: Object = config.get("animator", null) as Object
	if animator == null:
		return
	var sprite_state: Dictionary = _resolve_companion_sprite_state(config)
	var mode: String = str(sprite_state.get("mode", LingpetCompanionSpriteAnimator.MODE_WALK))
	var tex: Texture2D = sprite_state.get("texture", null) as Texture2D
	var visual_key := str(sprite_state.get("visual_key", "companion_walk"))
	var should_flip_sprite := bool(sprite_state.get("flip", false))
	var render_speed_ratio := float(sprite_state.get("speed_ratio", config.get("motion_speed_ratio", 0.0)))
	var distance_roll_sprite := bool(sprite_state.get("distance_roll", false))
	var bind_sheet := bool(sprite_state.get("bind_sheet", false))
	if tex == null:
		return
	var modulate := Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
	var draw_size_override: Vector2 = _get_draw_size_override(config, mode)
	if bind_sheet:
		_draw_bind_sheet_region(
			canvas,
			tex,
			center,
			_get_bind_sheet_draw_size(config),
			modulate,
			int(sprite_state.get("bind_cols", 4)),
			int(sprite_state.get("bind_rows", 4)),
			int(sprite_state.get("bind_frame", 0)),
			int(sprite_state.get("bind_frame_count", 16))
		)
		return
	if distance_roll_sprite:
		_draw_distance_roll_texture_region(
			canvas,
			tex,
			center,
			mode,
			draw_size_override,
			modulate,
			float(sprite_state.get("rotation", config.get("companion_roll_angle", 0.0))),
			should_flip_sprite
		)
		return
	var sheet_meta := _get_sheet_meta(config, visual_key)
	var rects: Dictionary = animator.build_draw_rects(
		tex,
		mode,
		center,
		float(config.get("patrol_pause", 0.0)),
		float(config.get("windup_elapsed", 0.0)),
		float(config.get("windup_seconds", 0.0)),
		render_speed_ratio,
		draw_size_override,
		sheet_meta
	)
	if rects.is_empty():
		return
	var dest_rect: Rect2 = apply_puppet_control_y_offset_delta(
		rects.get("dest", Rect2()),
		visual_key,
		config
	)
	var source_rect: Rect2 = rects.get("source", Rect2())
	# Dedicated movement sheets render as-authored. Legacy sheets mirror through
	# UVs for left-facing walk / strike / cast fallbacks. Passing a negative Rect2
	# width to
	# draw_texture_rect_region can shift the visible sheet away from the collision
	# center on some draw paths, so the flip stays UV-swapped.
	if should_flip_sprite:
		_draw_flipped_texture_region(canvas, tex, source_rect, dest_rect, modulate)
	else:
		canvas.draw_texture_rect_region(tex, dest_rect, source_rect, modulate, false, true)


# Exhausted (KO) pets lie flat on the ground instead of standing (live QA
# 2026-07-04: the old y-squash still read as "standing but idle").
# draw_texture_rect_region cannot rotate and draw_set_transform is banned in
# _draw paths (identity-reset trap), so build the rotated quad vertices
# directly and map the sheet cell through NORMALIZED UVs (raw pixel UVs
# silently clamp — draw_polygon UV trap).
	# 90° rotation: screen-space axes for the sprite's local +x (right) and +y (down).
	# head_dir picks which side the head falls toward, following the facing flip.


# E1-③ (묵린변신): launch-flash palette by style STRING. The empty / unknown
# style returns EXACTLY the shipped cyan trio, so every existing pet is
# pixel-identical; "mokrin_ink" swaps to the dark ink family. Single resolver
# on purpose — palette values must never fork per call site.
static func resolve_skill_flash_palette(style: String) -> Dictionary:
	if style == "mokrin_ink":
		return {
			"fill": Color(0.13, 0.12, 0.17),
			"arc": Color(0.42, 0.37, 0.52),
			"burst": Color(0.30, 0.26, 0.40),
		}
	return {
		"fill": Color(0.24, 0.92, 1.0),
		"arc": Color(0.72, 1.0, 1.0),
		"burst": Color(0.54, 1.0, 1.0),
	}


# D5c (묵린변신): absorb the WALK(-6) -> CAST(-12) animator Y-offset gap so the
# transform sheet does not pop 6px up on activation. Applies ONLY to the
# companion_puppet_control visual key with a POSITIVE per-profile delta
# (no key = 0 = every existing pet renders exactly as before). Public and
# static so the seal can drive the same function the draw path uses.
static func apply_puppet_control_y_offset_delta(dest_rect: Rect2, visual_key: String, config: Dictionary) -> Rect2:
	if visual_key != "companion_puppet_control":
		return dest_rect
	var delta: float = float(config.get("companion_puppet_control_y_offset_delta", 0.0))
	if delta <= 0.0:
		return dest_rect
	dest_rect.position.y += delta
	return dest_rect


func resolve_companion_sprite_state_for_tests(config: Dictionary) -> Dictionary:
	return _resolve_companion_sprite_state(config)


func _resolve_companion_sprite_state(config: Dictionary) -> Dictionary:
	var mode := LingpetCompanionSpriteAnimator.MODE_WALK
	var tex: Texture2D = config.get("walk_texture", null) as Texture2D
	var visual_key := "companion_walk"
	var facing_left := bool(config.get("face_left", false))
	var should_flip_sprite := false
	var render_speed_ratio := float(config.get("motion_speed_ratio", 0.0))
	var distance_roll_sprite := false
	var bind_sheet := false
	if bool(config.get("casting_windup", false)):
		mode = LingpetCompanionSpriteAnimator.MODE_CAST
		tex = config.get("cast_texture", null) as Texture2D
		visual_key = "companion_puppet_control" if bool(config.get("skill_cast_pose_active", false)) else "companion_cast"
		should_flip_sprite = facing_left
	elif bool(config.get("bind_sheet_active", false)) and config.get("bind_sheet_texture", null) != null:
		# Star Coil BIND: orosha body itself wraps the boss (animated bind sheet) instead of the
		# rolling-hoop sprite. Takes priority over distance_roll while binding.
		tex = config.get("bind_sheet_texture", null) as Texture2D
		visual_key = "companion_star_coil_bind"
		bind_sheet = true
	else:
		var distance_roll_state := _get_distance_roll_texture_state(config)
		if not distance_roll_state.is_empty():
			tex = distance_roll_state.get("texture", null) as Texture2D
			visual_key = str(distance_roll_state.get("visual_key", visual_key))
			should_flip_sprite = bool(distance_roll_state.get("flip", false))
			distance_roll_sprite = true
		elif bool(config.get("attacking", false)):
			mode = LingpetCompanionSpriteAnimator.MODE_STRIKE
			tex = config.get("strike_texture", null) as Texture2D
			visual_key = "companion_strike"
			should_flip_sprite = facing_left
		else:
			var moving := render_speed_ratio > LingpetCompanionSpriteAnimator.MOVING_RATIO_THRESHOLD
			if not moving:
				var freeze_move_frame := float(config.get("companion_stop_freeze_move_frame", 0.0)) > 0.0
				if freeze_move_frame:
					var move_state := _get_movement_texture_state(config, facing_left)
					if not move_state.is_empty():
						tex = move_state.get("texture", null) as Texture2D
						visual_key = str(move_state.get("visual_key", visual_key))
						should_flip_sprite = bool(move_state.get("flip", false))
						render_speed_ratio = maxf(render_speed_ratio, LingpetCompanionSpriteAnimator.MOVING_RATIO_THRESHOLD + 0.001)
					else:
						var idle_tex: Texture2D = config.get("idle_texture", null) as Texture2D
						if idle_tex != null:
							tex = idle_tex
							visual_key = "companion_idle"
						else:
							should_flip_sprite = facing_left
				else:
					var idle_tex: Texture2D = config.get("idle_texture", null) as Texture2D
					if idle_tex != null:
						tex = idle_tex
						visual_key = "companion_idle"
					else:
						should_flip_sprite = facing_left
			else:
				var moving_state := _get_movement_texture_state(config, facing_left)
				if not moving_state.is_empty():
					tex = moving_state.get("texture", null) as Texture2D
					visual_key = str(moving_state.get("visual_key", visual_key))
					should_flip_sprite = bool(moving_state.get("flip", false))
	return {
		"mode": mode,
		"texture": tex,
		"visual_key": visual_key,
		"flip": should_flip_sprite,
		"speed_ratio": render_speed_ratio,
		"distance_roll": distance_roll_sprite,
		"rotation": float(config.get("companion_roll_angle", 0.0)),
		"bind_sheet": bind_sheet,
		"bind_cols": int(config.get("companion_star_coil_bind_cols", 0)),
		"bind_rows": int(config.get("companion_star_coil_bind_rows", 0)),
		"bind_frame": int(config.get("bind_sheet_frame", 0)),
		"bind_frame_count": int(config.get("companion_star_coil_bind_frame_count", 0)),
	}


func _get_distance_roll_texture_state(config: Dictionary) -> Dictionary:
	if float(config.get("companion_distance_roll_enabled", 0.0)) <= 0.0:
		return {}
	var roll_tex: Texture2D = config.get("distance_roll_source_texture", null) as Texture2D
	if roll_tex == null:
		return {}
	return {
		"texture": roll_tex,
		"visual_key": "companion_distance_roll_source",
		"flip": false,
	}


func _get_bind_sheet_draw_size(config: Dictionary) -> Vector2:
	var s: float = float(config.get("companion_star_coil_bind_draw_size", 0.0))
	if s <= 0.0:
		return LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE
	return Vector2(s, s)


func _draw_bind_sheet_region(canvas: CanvasItem, texture: Texture2D, center: Vector2, draw_size: Vector2, modulate: Color, cols: int, rows: int, frame: int, frame_count: int) -> void:
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or cols <= 0 or rows <= 0:
		return
	var total: int = frame_count if frame_count > 0 else cols * rows
	if total <= 0:
		total = 1
	var idx: int = ((frame % total) + total) % total
	var cell_w: float = tex_size.x / float(cols)
	var cell_h: float = tex_size.y / float(rows)
	var cx: int = idx % cols
	var cy: int = floori(float(idx) / float(cols))
	var source_rect := Rect2(float(cx) * cell_w, float(cy) * cell_h, cell_w, cell_h)
	var dest_size: Vector2 = draw_size if draw_size != Vector2.ZERO else LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE
	var dest_rect := Rect2(center - dest_size * 0.5, dest_size)
	canvas.draw_texture_rect_region(texture, dest_rect, source_rect, modulate, false, true)


func _get_movement_texture_state(config: Dictionary, facing_left: bool) -> Dictionary:
	if facing_left:
		var move_left_tex: Texture2D = config.get("move_left_texture", null) as Texture2D
		if move_left_tex != null:
			return {
				"texture": move_left_tex,
				"visual_key": "companion_move_left",
				"flip": false,
			}
	else:
		var move_right_tex: Texture2D = config.get("move_right_texture", null) as Texture2D
		if move_right_tex != null:
			return {
				"texture": move_right_tex,
				"visual_key": "companion_move_right",
				"flip": false,
			}
	var walk_tex: Texture2D = config.get("walk_texture", null) as Texture2D
	if walk_tex == null:
		return {}
	return {
		"texture": walk_tex,
		"visual_key": "companion_walk",
		"flip": facing_left,
	}


func _get_draw_size_override(config: Dictionary, mode: String) -> Vector2:
	var key := "walk_draw_size"
	match mode:
		LingpetCompanionSpriteAnimator.MODE_CAST:
			key = "cast_draw_size"
		LingpetCompanionSpriteAnimator.MODE_STRIKE:
			key = "strike_draw_size"
	var draw_size: float = float(config.get(key, 0.0))
	if draw_size <= 0.0:
		return Vector2.ZERO
	return Vector2(draw_size, draw_size)


func _draw_distance_roll_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	mode: String,
	draw_size_override: Vector2,
	modulate: Color,
	rotation_radians: float,
	flip_h: bool = false
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var draw_size: Vector2 = draw_size_override
	if draw_size == Vector2.ZERO:
		draw_size = _get_default_draw_size_for_mode(mode)
	var dest_rect := Rect2(center - draw_size * 0.5 + Vector2(0.0, _get_y_offset_for_mode(mode)), draw_size)
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	_draw_texture_rect_region_rotated(canvas, texture, source_rect, dest_rect, modulate, rotation_radians, flip_h)


func _get_default_draw_size_for_mode(mode: String) -> Vector2:
	match mode:
		LingpetCompanionSpriteAnimator.MODE_CAST:
			return LingpetCompanionSpriteAnimator.CAST_DRAW_SIZE
		LingpetCompanionSpriteAnimator.MODE_STRIKE:
			return LingpetCompanionSpriteAnimator.STRIKE_DRAW_SIZE
		_:
			return LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE


func _get_y_offset_for_mode(mode: String) -> float:
	match mode:
		LingpetCompanionSpriteAnimator.MODE_CAST:
			return LingpetCompanionSpriteAnimator.CAST_Y_OFFSET
		LingpetCompanionSpriteAnimator.MODE_STRIKE:
			return LingpetCompanionSpriteAnimator.STRIKE_Y_OFFSET
		_:
			return LingpetCompanionSpriteAnimator.WALK_Y_OFFSET


func _get_sheet_meta(config: Dictionary, visual_key: String) -> Dictionary:
	var cols := int(config.get("%s_cols" % visual_key, 0))
	var rows := int(config.get("%s_rows" % visual_key, 0))
	var frame_count := int(config.get("%s_frame_count" % visual_key, 0))
	if cols <= 0 and rows <= 0 and frame_count <= 0:
		return {}
	var meta: Dictionary = {}
	if cols > 0:
		meta["cols"] = cols
	if rows > 0:
		meta["rows"] = rows
	if frame_count > 0:
		meta["frame_count"] = frame_count
	return meta


func _draw_texture_rect_region_rotated(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color,
	rotation_radians: float,
	flip_h: bool = false
) -> void:
	if absf(rotation_radians) <= 0.0001:
		if flip_h:
			_draw_flipped_texture_region(canvas, texture, source_rect, target_rect, modulate)
		else:
			canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var pivot := target_rect.position + target_rect.size * 0.5
	var cos_r: float = cos(rotation_radians)
	var sin_r: float = sin(rotation_radians)
	var corners := [
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		var offset: Vector2 = corner - pivot
		points.append(pivot + Vector2(
			offset.x * cos_r - offset.y * sin_r,
			offset.x * sin_r + offset.y * cos_r
		))
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x if flip_h else uv_min.x, uv_min.y),
		Vector2(uv_min.x if flip_h else uv_max.x, uv_min.y),
		Vector2(uv_min.x if flip_h else uv_max.x, uv_max.y),
		Vector2(uv_max.x if flip_h else uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_burst(
	canvas: CanvasItem,
	center: Vector2,
	flash_ratio: float,
	particle_count: int,
	trigger_count: int,
	tint: Color,
	is_gauge: bool
) -> void:
	var safe_count: int = maxi(1, particle_count)
	var expansion: float = 1.0 - flash_ratio
	var phase_offset: float = float(trigger_count % 5) * (0.19 if is_gauge else 0.17)
	var start_min: float = 8.0 if is_gauge else 10.0
	var start_max: float = 16.0 if is_gauge else 20.0
	var end_min: float = 18.0 if is_gauge else 22.0
	var end_max: float = 42.0 if is_gauge else 52.0
	var alpha: float = (0.58 if is_gauge else 0.62) * flash_ratio
	var line_width: float = (2.0 if is_gauge else 2.2) * flash_ratio
	var dot_radius: float = (2.4 if is_gauge else 2.6) * flash_ratio
	for i in range(safe_count):
		var angle: float = TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var ray_start: Vector2 = center + dir * lerpf(start_min, start_max, expansion)
		var ray_end: Vector2 = center + dir * lerpf(end_min, end_max, expansion)
		var line_color := Color(tint.r, tint.g, tint.b, alpha)
		var dot_color := Color(1.0, 0.98, 0.62, alpha) if is_gauge else Color(0.88, 1.0, 1.0, alpha)
		canvas.draw_line(ray_start, ray_end, line_color, maxf(1.0, line_width), true)
		canvas.draw_circle(ray_end, maxf(1.1 if is_gauge else 1.2, dot_radius), dot_color)


func _draw_switch_transition(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	switch_ratio: float,
	particle_count: int,
	trigger_count: int
) -> void:
	var ratio := clampf(switch_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var progress := 1.0 - ratio
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var pulse := sin(progress * PI)
	var ring_radius := lerpf(radius + 58.0, radius + 18.0, eased)
	var ring_alpha := 0.16 + 0.28 * ratio + 0.14 * pulse
	canvas.draw_circle(center, ring_radius, Color(0.08, 0.64, 0.72, 0.10 * ratio))
	canvas.draw_arc(center, ring_radius, -PI * 0.5 + progress * TAU, PI * 1.35 + progress * TAU, 36, Color(0.42, 1.0, 0.96, ring_alpha), 2.4, true)
	canvas.draw_arc(center, ring_radius * 0.62, PI * 0.25 - progress * TAU, PI * 1.55 - progress * TAU, 32, Color(0.72, 1.0, 0.82, 0.32 * ratio), 1.8, true)
	var safe_count := maxi(4, particle_count)
	var phase_offset := float(trigger_count % 7) * 0.31
	for i in range(safe_count):
		var angle := TAU * float(i) / float(safe_count) + phase_offset
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var scatter := lerpf(radius + 66.0, radius + 10.0, eased)
		var wobble := sin(progress * TAU * 2.1 + float(i) * 1.77 + phase_offset) * lerpf(8.0, 2.0, eased)
		var shard_pos := center + dir * scatter + tangent * wobble
		var shard_target := center + dir * lerpf(radius + 18.0, radius + 4.0, eased)
		var shard_alpha := (0.26 + 0.34 * pulse) * ratio
		var shard_size := lerpf(3.0, 1.4, eased)
		canvas.draw_line(shard_pos, shard_target, Color(0.38, 1.0, 0.94, shard_alpha), maxf(1.0, 1.7 * ratio), true)
		canvas.draw_circle(shard_pos, maxf(1.0, shard_size), Color(0.82, 1.0, 0.88, minf(0.88, shard_alpha + 0.18)))


func _draw_switch_label(canvas: CanvasItem, center: Vector2, display_name: String, switch_ratio: float) -> void:
	var name := display_name.strip_edges()
	if name == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var ratio := clampf(switch_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var progress := 1.0 - ratio
	var alpha := clampf(sin(progress * PI) * 1.35, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var font_size := 14
	var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var pos := center + Vector2(-width * 0.5, -62.0 - 8.0 * sin(progress * PI))
	var bg_rect := Rect2(pos + Vector2(-8.0, -font_size - 6.0), Vector2(width + 16.0, float(font_size) + 12.0))
	canvas.draw_rect(bg_rect, Color(0.015, 0.035, 0.052, 0.58 * alpha))
	canvas.draw_rect(bg_rect, Color(0.42, 1.0, 0.94, 0.62 * alpha), false, 1.4)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.58 * alpha))
	canvas.draw_string(font, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.78, 1.0, 0.95, 0.96 * alpha))


func _draw_guard_label(canvas: CanvasItem, popup: Variant, shake_offset: Vector2) -> void:
	if not popup is Dictionary:
		return
	var data: Dictionary = popup
	if data.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := LanguageSettings.translate_text(str(data.get("text", "")).strip_edges())
	if text == "":
		return
	var ratio := clampf(float(data.get("ratio", 0.0)), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - ratio, 2.0)
	var fade_start := 0.60
	var alpha := 1.0 if ratio <= fade_start else clampf(1.0 - (ratio - fade_start) / maxf(0.001, 1.0 - fade_start), 0.0, 1.0)
	if alpha <= 0.01:
		return
	var pos := _get_vector2(data.get("position", Vector2.ZERO), Vector2.ZERO)
	var font_size := 12
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var draw_pos := pos + shake_offset + Vector2(-width * 0.5, -18.0 - 16.0 * eased)
	canvas.draw_string(font, draw_pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.60 * alpha))
	canvas.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.42, 0.20, 0.96 * alpha))
