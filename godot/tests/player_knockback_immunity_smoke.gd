extends SceneTree

# Seals the shared 부동갑주 hostile-hit immunity gates:
#  - blocks hostile knockback via celestial armor through the owner path
#    (effects/weather pipeline) AND the context-gauge path (ball pipeline),
#  - stun-bearing hits are gated as a WHOLE hit (try_block_player_stun): one
#    armor proc skips stun AND knockback together — a partial block ("wave
#    played but I still got stunned", the reported hail / hongryun fireball
#    bug) must be impossible,
#  - honors smasher cleanse immunity without spending gauge,
#  - does nothing when no armor / no cleanse is present,
#  - and verifies every hostile-hazard site calls the gate matching its hit
#    shape (stun-bearing -> stun gate, knockback-only -> knockback gate).

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")
const Stage5HongryunState := preload("res://scripts/stages/stage5/stage5_hongryun_state.gd")
const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")
const LingpetBombSurpriseSkill := preload("res://scripts/lingpet/lingpet_bomb_surprise_skill.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var celestial_armor_equipped := false
	var celestial_armor_active := false
	var celestial_armor_trigger_chance_pct := 0.0
	var celestial_armor_gauge_cost := 0.0
	var celestial_armor_context: Dictionary = {}
	var celestial_armor_wave_active := false

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class CleanseImmune:
	func is_immune() -> bool:
		return true


class StatusCapture:
	var calls: Array = []

	func apply_status(target: String, effect: String, frames: float, meta: Dictionary = {}, source: String = "") -> void:
		calls.append({
			"target": target,
			"effect": effect,
			"frames": frames,
			"meta": meta,
			"source": source,
		})


class MovementCapture:
	var calls: Array = []

	func start_knockback(velocity: float, frames: float, decay: float, _interrupt_dash: bool = true, _allow_stack: bool = true) -> void:
		calls.append({"velocity": velocity, "frames": frames, "decay": decay})


class AudioCapture:
	var hurt_calls := 0

	func play_stage5_hongryun_hurt() -> void:
		hurt_calls += 1


func _init() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should equip for the immunity gate test"
	)

	var deps := {"mythic_item_runtime": runtime, "registry": registry}

	# Owner path (effects / weather pipeline): gauge lives on the owner object.
	_expect(
		PlayerKnockbackImmunity.try_block_player_knockback(deps, {"owner": owner}, "hazard_owner"),
		"helper should block hostile knockback via celestial armor (owner path)"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "owner-path block should spend owner gauge")

	# Context path (ball pipeline): no owner object, gauge lives in a scene dict.
	runtime.reset_round(registry)
	var scene := {
		"special_gauge": 50.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	_expect(
		PlayerKnockbackImmunity.try_block_player_knockback(deps, scene, "hazard_ball"),
		"helper should block hostile knockback via celestial armor (context gauge path)"
	)
	_expect(is_equal_approx(float(scene.get("special_gauge", -1.0)), 30.0), "context-path block should spend scene gauge")

	# Whole-hit stun gate: stun-bearing hits roll ONCE for the whole hit.
	runtime.reset_round(registry)
	_expect(
		PlayerKnockbackImmunity.try_block_player_stun(deps, {"owner": owner}, "hazard_stun_hit"),
		"stun gate should block a stun-bearing hit via celestial armor"
	)
	_expect(is_equal_approx(owner.special_gauge, 60.0), "stun-gate block should spend owner gauge")

	_verify_hongryun_hit_whole_block(runtime, registry)
	_verify_hail_hit_whole_block(runtime, registry, owner)
	_verify_volty_self_explosion_whole_block(runtime, registry, owner)

	# Cleanse is a SEPARATE full-immunity gate (is_cleanse_immune), NOT folded
	# into the armor bools. Callers gate the whole hit on it.
	_expect(
		PlayerKnockbackImmunity.is_cleanse_immune({"smasher_cleanse_state": CleanseImmune.new()}, {}),
		"is_cleanse_immune should report an active cleanse window"
	)
	_expect(
		not PlayerKnockbackImmunity.is_cleanse_immune(deps, {"owner": owner}),
		"is_cleanse_immune should be false with no cleanse state"
	)

	# The armor gate must be cleanse-INDEPENDENT: with the armor gone, cleanse in
	# deps must not make try_block_player_knockback report a block.
	runtime.reset_round(registry)
	owner.special_gauge = 100.0
	_expect(runtime.unequip_item("celestial_armor", owner, registry), "celestial armor should unequip")
	var armorless_cleanse_deps := {
		"mythic_item_runtime": runtime,
		"registry": registry,
		"smasher_cleanse_state": CleanseImmune.new(),
	}
	_expect(
		not PlayerKnockbackImmunity.try_block_player_knockback(armorless_cleanse_deps, {"owner": owner}, "hazard_none"),
		"armor gate must be cleanse-independent (no armor -> no block, even under cleanse)"
	)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "armorless gate should not spend gauge")

	_verify_sites_wired()
	print("player_knockback_immunity_smoke: ok")
	quit(0)


func _verify_hongryun_hit_whole_block(runtime: Object, registry: Object) -> void:
	# Reported bug repro: 홍련 화염탄 hit with 부동갑주 procced must skip the
	# ENTIRE hit — not only stun/knockback but ALSO the public-path side effects
	# (dragon-orb charge + hurt SFX) that fire in register_fireball_hit_player.
	# Drives the real public entry (_resolve_fireball_player_hit), not just the
	# private stun helper, so the register-before-gate ordering is sealed.
	runtime.reset_round(registry)
	var state := Stage5HongryunState.new()
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	var audio := AudioCapture.new()
	var deps := {
		"mythic_item_runtime": runtime,
		"registry": registry,
		"status_effect_state": status,
		"movement_state": movement,
		"audio": audio,
	}
	# Ball-pipeline shape: no owner object, gauge rides the context dict.
	var context := {
		"special_gauge": 60.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	var orb_before: float = state.dragon_orb_count
	var result := {}
	state._resolve_fireball_player_hit(Vector2(300.0, 690.0), context, deps, result)
	_expect(
		bool(result.get("stage5_hongryun_player_hit_blocked_by_armor", false)),
		"hongryun fireball should report the armor whole-hit block"
	)
	_expect(status.calls.is_empty(), "armor-blocked fireball must NOT apply the stun")
	_expect(movement.calls.is_empty(), "armor-blocked fireball must NOT apply the knockback")
	_expect(
		not bool(result.get("stage5_hongryun_player_stunned", false)),
		"armor-blocked fireball must not report a player stun"
	)
	_expect(
		not bool(result.get("stage5_hongryun_fireball_hit_player", false)),
		"armor-blocked fireball must not report a landed hit (the hit never landed)"
	)
	_expect(
		is_equal_approx(state.dragon_orb_count, orb_before),
		"armor-blocked fireball must NOT charge the dragon orb (register skipped)"
	)
	_expect(audio.hurt_calls == 0, "armor-blocked fireball must NOT play the hurt SFX (register skipped)")
	_expect(
		is_zero_approx(state.player_fireball_stun_immunity_timer),
		"armor-blocked fireball must not arm the fireball immunity timer (the hit never landed)"
	)
	_expect(is_equal_approx(float(context.get("special_gauge", -1.0)), 40.0), "armor block should spend context gauge")

	# Without armor the same fireball lands fully: stun + knockback + dragon-orb
	# charge + hurt SFX + immunity-timer arm, each exactly once.
	var bare_state := Stage5HongryunState.new()
	var bare_status := StatusCapture.new()
	var bare_movement := MovementCapture.new()
	var bare_audio := AudioCapture.new()
	var bare_deps := {
		"status_effect_state": bare_status,
		"movement_state": bare_movement,
		"audio": bare_audio,
	}
	var bare_orb_before: float = bare_state.dragon_orb_count
	var bare_result := {}
	bare_state._resolve_fireball_player_hit(Vector2(300.0, 690.0), {}, bare_deps, bare_result)
	_expect(bare_status.calls.size() == 1, "armorless fireball should apply exactly one stun")
	if bare_status.calls.size() == 1:
		_expect(String(bare_status.calls[0].get("effect", "")) == "stun", "armorless fireball should apply a stun status")
	_expect(bare_movement.calls.size() == 1, "armorless fireball should apply exactly one knockback")
	_expect(bool(bare_result.get("stage5_hongryun_player_stunned", false)), "armorless fireball should report the stun")
	_expect(bool(bare_result.get("stage5_hongryun_fireball_hit_player", false)), "armorless fireball should report a landed hit")
	_expect(bare_state.dragon_orb_count > bare_orb_before, "armorless fireball should charge the dragon orb")
	_expect(bare_audio.hurt_calls == 1, "armorless fireball should play the hurt SFX")
	_expect(
		bare_state.player_fireball_stun_immunity_timer > 0.0,
		"armorless fireball should arm the fireball immunity timer"
	)


func _verify_hail_hit_whole_block(runtime: Object, registry: FakeRegistry, owner: FakeOwner) -> void:
	# Reported bug repro: 우박 hit with 부동갑주 procced must skip the STUN
	# too, not only the knockback (real _apply_hail_player_hit).
	runtime.reset_round(registry)
	owner.special_gauge = 60.0
	var weather := WeatherEventState.new()
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	registry.instances = {
		"mythic_item_runtime": runtime,
		"status_effect_state": status,
		"player_movement_state": movement,
	}
	weather._apply_hail_player_hit(owner, registry)
	_expect(status.calls.is_empty(), "armor-blocked hail hit must NOT apply the stun")
	_expect(movement.calls.is_empty(), "armor-blocked hail hit must NOT apply the knockback")
	_expect(is_equal_approx(owner.special_gauge, 40.0), "hail armor block should spend owner gauge")

	# Without armor the same hail hit applies stun AND knockback exactly once.
	registry.instances = {
		"status_effect_state": status,
		"player_movement_state": movement,
	}
	weather._apply_hail_player_hit(owner, registry)
	_expect(status.calls.size() == 1, "armorless hail hit should apply exactly one stun")
	if status.calls.size() == 1:
		_expect(String(status.calls[0].get("effect", "")) == "stun", "armorless hail hit should apply a stun status")
	_expect(movement.calls.size() == 1, "armorless hail hit should apply exactly one knockback")
	registry.instances = {}


func _verify_volty_self_explosion_whole_block(runtime: Object, registry: FakeRegistry, owner: FakeOwner) -> void:
	# 볼탄 폭탄 서프라이즈 self-explosion (LOCATION_BOTTOM) stuns + knocks the
	# player. 부동갑주 must block that incoming CC as a whole hit — the bomb
	# still detonates, but the player takes no stun/knockback.
	runtime.reset_round(registry)
	owner.special_gauge = 60.0
	var skill := LingpetBombSurpriseSkill.new()
	var status := StatusCapture.new()
	var movement := MovementCapture.new()
	registry.instances = {
		"mythic_item_runtime": runtime,
		"status_effect_state": status,
		"player_movement_state": movement,
	}
	skill._apply_explosion_status(owner, registry, "bottom", true)
	_expect(status.calls.is_empty(), "armor-blocked volty self-explosion must NOT apply the stun")
	_expect(movement.calls.is_empty(), "armor-blocked volty self-explosion must NOT apply the knockback")
	_expect(is_equal_approx(owner.special_gauge, 40.0), "volty self-explosion armor block should spend owner gauge")
	_expect(is_zero_approx(skill._last_stun_frames), "armor-blocked volty self-explosion must clear the reported stun frames")
	_expect(is_zero_approx(skill._last_knockback_velocity), "armor-blocked volty self-explosion must clear the reported knockback")

	# Without armor the self-explosion applies stun AND knockback exactly once.
	var bare_skill := LingpetBombSurpriseSkill.new()
	var bare_status := StatusCapture.new()
	var bare_movement := MovementCapture.new()
	registry.instances = {
		"status_effect_state": bare_status,
		"player_movement_state": bare_movement,
	}
	bare_skill._apply_explosion_status(owner, registry, "bottom", true)
	_expect(bare_status.calls.size() == 1, "armorless volty self-explosion should apply exactly one stun")
	if bare_status.calls.size() == 1:
		_expect(String(bare_status.calls[0].get("effect", "")) == "stun", "armorless volty self-explosion should apply a stun status")
	_expect(bare_movement.calls.size() == 1, "armorless volty self-explosion should apply exactly one knockback")
	registry.instances = {}


func _verify_sites_wired() -> void:
	# Every hostile-hazard CC site must route through the shared gate MATCHING
	# its hit shape. Stun-bearing hits gate the WHOLE hit on the stun gate and
	# must NOT also roll the knockback gate (one armor roll per hit — a second
	# gate would reintroduce the partial-block bug this smoke seals).
	var stun_hit_sites := [
		"res://scripts/stages/stage5/stage5_hongryun_state.gd",
		"res://scripts/stages/stage1/stage1_gaksital_fan_throw_skill_state.gd",
		"res://scripts/stages/common/weather_event_state.gd",
		"res://scripts/lingpet/lingpet_bomb_surprise_skill.gd",
	]
	var knockback_only_sites := [
		"res://scripts/stages/stage4/stage4_moon_event.gd",
		"res://scripts/stages/stage5/stage5_hongryun_fire_machine_event.gd",
	]
	for path in stun_hit_sites:
		var src := FileAccess.get_file_as_string(path)
		_expect(src != "", "site source should be readable: %s" % path)
		_expect(
			src.contains("PlayerKnockbackImmunity.try_block_player_stun"),
			"stun-bearing hit site should gate the WHOLE hit on the armor stun gate: %s" % path
		)
		_expect(
			not src.contains("PlayerKnockbackImmunity.try_block_player_knockback"),
			"stun-bearing hit site must not double-roll the knockback gate: %s" % path
		)
		_expect(
			src.contains("PlayerKnockbackImmunity.is_cleanse_immune"),
			"stun-bearing hit site should also honor the cleanse whole-hit gate: %s" % path
		)
	for path in knockback_only_sites:
		var src := FileAccess.get_file_as_string(path)
		_expect(src != "", "site source should be readable: %s" % path)
		_expect(
			src.contains("PlayerKnockbackImmunity.try_block_player_knockback"),
			"knockback-only hit site should call the armor knockback gate: %s" % path
		)
		_expect(
			src.contains("PlayerKnockbackImmunity.is_cleanse_immune"),
			"knockback-only hit site should also honor the cleanse whole-hit gate: %s" % path
		)

	# The player-hit recoil must NOT be blocked: it is routed with "recoil".
	var router_src := FileAccess.get_file_as_string("res://scripts/ball/paddle_bounce_event_router.gd")
	_expect(router_src != "", "paddle bounce router source should be readable")
	_expect(router_src.contains("\"recoil\""), "paddle-hit recoil must route with the non-blockable 'recoil' effect type")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
