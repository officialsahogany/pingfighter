extends RefCounted

## Shared "boss is being electrocuted" body-reaction visual.
## Referenced via `const ElectricStunVisual := preload(...)` by the boss actor
## renderers (no global class_name, so headless test runs do not depend on the
## editor regenerating the global script class cache).
##
## The original PingFighter sold electrocution on the boss BODY: a fast
## per-frame tremble plus a cyan-white electric colour pulse, on top of the
## floating arc/spark overlays. The Godot port drew rich arcs (Ragnarok field
## renderer, Lumion thunder orb) but left the body still and full-colour, so the
## shock read as decoration around a calm boss rather than a convulsing one.
##
## This helper is the body-level half of that read. It is intentionally
## overlay-agnostic: each effect keeps drawing its own arcs; this only supplies
## the sprite jitter + tint so every electric-stun source feels the same.
##
## Sources (any active -> full intensity):
##   - ragnarok_hammer_electric_stun_active  (Ragnarok Hammer mythic; set by
##                                             mythic_item_context_builder)
##   - boss_electric_stun_active             (central status electric_stun:
##                                             Lumion thunder orb today, any
##                                             future skill that applies a
##                                             stun with electric_stun: true)
##
## Returns identity values (ZERO jitter / WHITE modulate) when no electric stun
## is active, so callers can apply it unconditionally with zero behaviour change.

const _JITTER_AMP_X := 1.5
const _JITTER_AMP_Y := 2.0


static func is_active(context: Dictionary) -> bool:
	return (
		bool(context.get("ragnarok_hammer_electric_stun_active", false))
		or bool(context.get("boss_electric_stun_active", false))
	)


static func intensity(context: Dictionary) -> float:
	return 1.0 if is_active(context) else 0.0


## Per-frame body tremble. High-frequency desynced sine terms plus a very fast
## "jolt" component so the shake reads as an electric convulsion that snaps
## frame-to-frame (the original used per-frame random +/-2..3 px) rather than a
## smooth low-frequency sway. Peak ~+/-3.1 px horizontal, ~+/-2.0 px vertical.
static func body_jitter(context: Dictionary) -> Vector2:
	var strength := intensity(context)
	if strength <= 0.0:
		return Vector2.ZERO
	var now := float(Time.get_ticks_msec())
	var buzz := sin(now * 0.21) + sin(now * 0.37) * 0.6
	var jolt := sin(now * 0.91) * 0.5
	return Vector2(
		(buzz + jolt) * _JITTER_AMP_X * strength,
		sin(now * 0.28) * _JITTER_AMP_Y * strength
	)


## Cyan-white electrified tint pulse for the boss sprite, in the same colour
## family as the existing Viper EMP tint (red pulled down, green/blue pushed
## past 1.0 to brighten). Multiply this into whatever modulate the renderer
## already passes; it is Color.WHITE (identity) when no electric stun is active.
static func body_modulate(context: Dictionary) -> Color:
	var strength := intensity(context)
	if strength <= 0.0:
		return Color.WHITE
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.03)
	return Color(
		lerp(1.0, 0.60, 0.40 * strength),
		lerp(1.0, 1.14, 0.30 * strength + pulse * 0.08),
		lerp(1.0, 1.32, 0.40 * strength + pulse * 0.10),
		1.0
	)
