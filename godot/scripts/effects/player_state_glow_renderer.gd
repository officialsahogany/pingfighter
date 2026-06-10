extends RefCounted

const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")

# Player "state glow": a soft alert aura drawn BEHIND the player body that lights
# up only on meaningful states, so the always-on bottom area stays uncluttered.
# Covers three states with a fixed precedence (danger > chain > transform).
# "chain" is the first skill-ready-class signal: Viper's dark blade chain window
# (viper_dark_blade_chain_glow_ratio from the viper actor draw context) lights the
# body crimson for the 1s combo window and fades with the remaining time.
#
# Sized off the VISIBLE draw rect (player sprite is ~160 px), NOT a gameplay hit
# radius -- otherwise the halo blooms entirely behind the body and reads as
# nothing (see feedback_godot_companion_vfx_size_basis). Three fully overlapping
# cos^2 layers form one smooth feathered halo (no discrete dots / rings), driven
# by a breathing ease; danger pulses a touch faster and stronger.

const GLOW_TEX_SIZE := 96

const STATE_NONE := ""
const STATE_DANGER := "danger"
const STATE_CHAIN := "chain"
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
	if state == STATE_CHAIN:
		amp *= 0.4 + 0.6 * clampf(float(context.get("viper_dark_blade_chain_glow_ratio", 0.0)), 0.0, 1.0)
	var rate: float = float(palette.get("rate", 0.0020))
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
	# so danger wins when both are active. The chain prompt is a short actionable
	# window, so it outranks the long-lived transform aura.
	if bool(context.get("player_in_danger", false)):
		return STATE_DANGER
	if float(context.get("viper_dark_blade_chain_glow_ratio", 0.0)) > 0.001:
		return STATE_CHAIN
	if bool(context.get("horn_strawberry_transformed", false)):
		return STATE_TRANSFORM
	return STATE_NONE


func _state_palette(state: String) -> Dictionary:
	if state == STATE_DANGER:
		# Alarm red, slightly stronger; overrides the character accent color.
		return {"tint": Color(1.0, 0.24, 0.20), "amp": 1.15, "rate": 0.0034}
	if state == STATE_CHAIN:
		# Dark blade chain prompt: deep crimson with an urgent pulse; the draw
		# path additionally fades amp with the remaining window ratio.
		return {"tint": Color(0.98, 0.12, 0.30), "amp": 1.1, "rate": 0.0048}
	# Transform: warm strawberry-pink "empowered" aura, distinct from danger red.
	return {"tint": Color(1.0, 0.46, 0.74), "amp": 1.0, "rate": 0.0020}


func _blit(canvas: CanvasItem, tex: Texture2D, center: Vector2, glow_radius: float, color: Color) -> void:
	var r: float = maxf(1.0, glow_radius)
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)
