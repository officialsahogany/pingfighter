extends SceneTree

# Guards the shared boss electrocution body-reaction visual: the jitter + cyan
# tint must fire for both electric-stun sources (Ragnarok Hammer mythic and the
# central electric_stun status used by Lumion's thunder orb), stay identity when
# inactive, and NOT fire for a plain (non-electric) stun.

const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_inactive_is_identity()
	_verify_ragnarok_flag_drives_body_reaction()
	_verify_central_electric_stun_flag_drives_body_reaction()
	_verify_central_status_propagates_electric_flag()
	_verify_plain_stun_does_not_electrify()

	if _failures.is_empty():
		print("boss_electric_stun_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_inactive_is_identity() -> void:
	var ctx := {}
	_expect(not ElectricStunVisual.is_active(ctx), "no flags should read as inactive")
	_expect(ElectricStunVisual.body_jitter(ctx) == Vector2.ZERO, "inactive electric stun should not jitter the boss body")
	_expect(ElectricStunVisual.body_modulate(ctx) == Color.WHITE, "inactive electric stun should leave the boss colour untouched")


func _verify_ragnarok_flag_drives_body_reaction() -> void:
	var ctx := {"ragnarok_hammer_electric_stun_active": true}
	_expect(ElectricStunVisual.is_active(ctx), "ragnarok electric stun flag should activate the shared body reaction")
	_expect_body_reaction(ctx, "ragnarok electric stun")


func _verify_central_electric_stun_flag_drives_body_reaction() -> void:
	var ctx := {"boss_electric_stun_active": true}
	_expect(ElectricStunVisual.is_active(ctx), "central electric stun flag should activate the shared body reaction")
	_expect_body_reaction(ctx, "central electric stun")


func _verify_central_status_propagates_electric_flag() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "stun", 12.0, {
		"electric_stun": true,
		"suppress_stun_stars": true,
	}, "lumion_thunder_orb_electric_stun")
	var ctx := status.get_actor_draw_context()
	_expect(bool(ctx.get("boss_electric_stun_active", false)), "central electric stun status should expose boss_electric_stun_active to the renderer context")
	_expect(bool(ctx.get("active_item_boss_stun_stars_suppressed", false)), "electric stun should still suppress the normal stun stars")
	_expect(ElectricStunVisual.is_active(ctx), "the propagated context should activate the shared body reaction")


func _verify_plain_stun_does_not_electrify() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "stun", 12.0, {}, "plain_grenade")
	var ctx := status.get_actor_draw_context()
	_expect(bool(ctx.get("active_item_boss_stun_active", false)), "a plain stun should still emit the normal stun context")
	_expect(not bool(ctx.get("boss_electric_stun_active", false)), "a non-electric stun should NOT set the electric flag")
	_expect(not ElectricStunVisual.is_active(ctx), "plain stun context should not activate the shared electric body reaction")


func _expect_body_reaction(ctx: Dictionary, label: String) -> void:
	# Jitter is wall-clock driven; sample a short window so the assertion does
	# not depend on the engine clock landing on a simultaneous sine zero.
	var saw_jitter := false
	for _i in range(8):
		if ElectricStunVisual.body_jitter(ctx).length() > 0.01:
			saw_jitter = true
			break
		OS.delay_msec(3)
	_expect(saw_jitter, "%s should tremble the boss body" % label)
	var tint := ElectricStunVisual.body_modulate(ctx)
	_expect(tint != Color.WHITE, "%s should tint the boss body away from white" % label)
	_expect(tint.b >= tint.r, "%s tint should push blue at least as high as red (electric cyan-white)" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
