extends RefCounted

const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

# Player "state glow": a soft alert aura drawn BEHIND the player body that lights
# up only on meaningful states, so the always-on bottom area stays uncluttered.
# v1 covers two states with a fixed precedence (danger > transform); skill-ready
# is a planned follow-up (its readiness signal is spread across per-character
# skill systems + the orb HUD, so it needs its own plumbing pass).
#
# Sized off the VISIBLE draw rect (player sprite is ~160 px), NOT a gameplay hit
# radius -- otherwise the halo blooms entirely behind the body and reads as
# nothing (see feedback_godot_companion_vfx_size_basis). Three fully overlapping
# cos^2 layers form one smooth feathered halo (no discrete dots / rings), driven
# by a breathing ease; danger pulses a touch faster and stronger.

const GLOW_TEX_SIZE := 96

const STATE_NONE := ""
const STATE_DANGER := "danger"
const STATE_TRANSFORM := "transform"


func prewarm() -> void:
	SoftGlowTexture.get_texture(GLOW_TEX_SIZE)


func draw(canvas: CanvasItem, visual_rect: Rect2, context: Dictionary, now_ms: float) -> void:
	if canvas == null or visual_rect.size.x <= 0.0:
		return
	# Skip during the defeat sequence so the match-point red aura does not bleed
	# into the lose animation.
	if bool(context.get("player_defeat_active", false)):
		return
	var state: String = resolve_state(context)
	if state == STATE_NONE:
		return
	var tex: Texture2D = SoftGlowTexture.get_texture(GLOW_TEX_SIZE)
	if tex == null:
		return
	# Anchor on the lower-mid of the draw box where the chibi body actually sits
	# (feet near the bottom of the 160 px sheet).
	var center := Vector2(
		visual_rect.position.x + visual_rect.size.x * 0.5,
		visual_rect.position.y + visual_rect.size.y * 0.6
	)
	var body_r: float = visual_rect.size.x * 0.30
	var palette: Dictionary = _state_palette(state)
	var tint: Color = palette.get("tint", Color(1.0, 1.0, 1.0, 1.0))
	var amp: float = float(palette.get("amp", 1.0))
	var rate: float = 0.0034 if state == STATE_DANGER else 0.0020
	var breath: float = 0.5 + 0.5 * sin(now_ms * rate)
	var outer_r: float = body_r + lerpf(40.0, 48.0, breath)
	var mid_r: float = body_r + lerpf(26.0, 32.0, breath)
	var core_r: float = body_r + lerpf(14.0, 18.0, breath)
	var outer_a: float = lerpf(0.055, 0.090, breath) * amp
	var mid_a: float = lerpf(0.110, 0.160, breath) * amp
	var core_a: float = lerpf(0.180, 0.260, breath) * amp
	_blit(canvas, tex, center, outer_r, Color(tint.r, tint.g, tint.b, outer_a))
	_blit(canvas, tex, center, mid_r, Color(tint.r, tint.g, tint.b, mid_a))
	_blit(canvas, tex, center, core_r, Color(tint.r, tint.g, tint.b, core_a))


func resolve_state(context: Dictionary) -> String:
	# Precedence: a match-point danger read matters more than the transform buff,
	# so danger wins when both are active.
	if bool(context.get("player_in_danger", false)):
		return STATE_DANGER
	if bool(context.get("horn_strawberry_transformed", false)):
		return STATE_TRANSFORM
	return STATE_NONE


func _state_palette(state: String) -> Dictionary:
	if state == STATE_DANGER:
		# Alarm red, slightly stronger; overrides the character accent color.
		return {"tint": Color(1.0, 0.24, 0.20), "amp": 1.15}
	# Transform: warm strawberry-pink "empowered" aura, distinct from danger red.
	return {"tint": Color(1.0, 0.46, 0.74), "amp": 1.0}


func _blit(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)
