extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmSuicideDroneState := preload("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BattleSceneEffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")
const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const Stage1CommandoFirearmFxHost := preload("res://scripts/stages/stage1/stage1_commando_firearm_fx_host.gd")
const Stage1CommandoFirearmRenderer := preload("res://scripts/stages/stage1/stage1_commando_firearm_renderer.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var shake_calls := 0
	var last_amount := 0.0
	var last_intensity := 0.0
	var shake_entries: Array = []
	var gauge_flash_calls := 0

	func update(_delta: float, _dash_token_max: int) -> void:
		pass

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_calls += 1
		last_amount = amount
		last_intensity = intensity
		shake_entries.append({"amount": amount, "intensity": intensity})

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1


class FakeImpactEffects:
	extends RefCounted

	var hits: Array = []

	func update(_delta: float) -> void:
		pass

	func spawn_hit_particles(pos: Vector2, color: Color, direction: Vector2 = Vector2.ZERO, intensity: float = 0.0, impact_speed: float = 0.0) -> void:
		hits.append({
			"pos": pos,
			"color": color,
			"direction": direction,
			"intensity": intensity,
			"impact_speed": impact_speed,
		})


class FakeBallEffects:
	extends RefCounted

	var pulses: Array = []

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float = 0.0, kind: String = "hit") -> void:
		pulses.append({
			"pos": pos,
			"velocity": velocity,
			"intensity": intensity,
			"kind": kind,
		})


class FakeAnimationState:
	extends RefCounted

	var boss_hit_calls := 0
	var last_boss_vel := 0.0
	var last_has_hit_texture := false

	func update(_delta: float, _context: Dictionary = {}) -> void:
		pass

	func trigger_boss_hit(boss_vel: float, has_hit_texture: bool) -> void:
		boss_hit_calls += 1
		last_boss_vel = boss_vel
		last_has_hit_texture = has_hit_texture


class FakeAudio:
	extends RefCounted

	var fire_calls: Array = []
	var impact_calls: Array = []
	var fire_support_radio_calls := 0
	var fire_support_aircraft_play_calls := 0
	var fire_support_aircraft_stop_calls := 0
	var supply_radio_calls := 0
	var supply_aircraft_play_calls := 0
	var supply_aircraft_stop_calls := 0
	var pistol_ready_calls := 0
	var pistol_reload_start_calls := 0
	var pistol_reload_round_calls := 0
	var suicide_drone_launch_calls := 0
	var suicide_drone_stop_calls := 0
	var suicide_drone_explosion_calls := 0

	func update(_delta: float) -> void:
		pass

	func play_commando_firearm_fire(weapon_id: String) -> void:
		fire_calls.append(weapon_id)

	func play_commando_firearm_impact(weapon_id: String) -> void:
		impact_calls.append(weapon_id)

	func play_commando_slingshot_impact() -> void:
		impact_calls.append("slingshot_impact")

	func play_commando_pistol_ready() -> void:
		pistol_ready_calls += 1

	func play_commando_pistol_reload_start() -> void:
		pistol_reload_start_calls += 1

	func play_commando_pistol_reload_round() -> void:
		pistol_reload_round_calls += 1

	func play_commando_fire_support_radio() -> void:
		fire_support_radio_calls += 1

	func play_commando_fire_support_aircraft_loop() -> void:
		fire_support_aircraft_play_calls += 1

	func stop_commando_fire_support_aircraft_loop() -> void:
		fire_support_aircraft_stop_calls += 1

	func play_commando_supply_radio() -> void:
		supply_radio_calls += 1

	func play_commando_supply_aircraft_loop() -> void:
		supply_aircraft_play_calls += 1

	func stop_commando_supply_aircraft_loop() -> void:
		supply_aircraft_stop_calls += 1

	func play_commando_suicide_drone_launch() -> void:
		fire_calls.append("suicide_drone")
		suicide_drone_launch_calls += 1

	func stop_commando_suicide_drone_loop() -> void:
		suicide_drone_stop_calls += 1

	func play_commando_suicide_drone_explosion() -> void:
		impact_calls.append("suicide_drone")
		suicide_drone_explosion_calls += 1


class FakeStatusEffectState:
	extends RefCounted

	var applied: Array = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		applied.append({
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		})
		return {}

	func get_calls_for_source(source_prefix: String) -> Array:
		var matches: Array = []
		@warning_ignore("shadowed_variable_base_class")
		for call in applied:
			var call_dict: Dictionary = call if call is Dictionary else {}
			var call_source: String = str(call_dict.get("source", ""))
			if call_source.begins_with(source_prefix):
				matches.append(call)
		return matches


class FakeAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace_current := false

	func start_paddle_hit_knockback(
		velocity: float,
		frames: float = 36.0,
		decay_per_frame: float = 0.85,
		replace_current: bool = true
	) -> void:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace_current = replace_current


class FakeActiveItemRuntime:
	extends RefCounted

	var molotov_fire_zone_calls: Array = []

	func trigger_molotov_fire_zone(
		center: Vector2,
		_owner: Object = null,
		_registry: Object = null,
		play_feedback_audio: bool = true
	) -> void:
		molotov_fire_zone_calls.append({
			"center": center,
			"play_feedback_audio": play_feedback_audio,
		})


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeOwner:
	extends RefCounted

	var drive_text_timer_frames := 0.0
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var skip_ball_motion_step := false
	var commando_bowling_trap_guard_armed := false
	var commando_bowling_trap_guard_source := ""
	var commando_bowling_trap_guard_knockback_power := 0.0
	var commando_bowling_trap_guard_stun_frames := 0.0
	var commando_bowling_trap_guard_restore_speed := 0.0
	var commando_suicide_drone_ball_boost_active := false
	var commando_suicide_drone_ball_restore_speed := 0.0
	var commando_suicide_drone_ball_boosted_speed := 0.0


func _init() -> void:
	var original_language := LanguageSettings.get_language()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_successful_fire_spawns_visible_runtime()
	_verify_bazooka_wall_impact_detonates_without_boss_contact()
	_verify_bazooka_edge_only_wall_blast_does_not_stun()
	_verify_fire_support_edge_only_blast_does_not_stun()
	_verify_suicide_drone_edge_only_blast_does_not_stun()
	_verify_net_gun_ammo_rope_capture_and_break()
	_verify_net_field_fill_guard_rejects_degenerate_polygon()
	_verify_ak47_shell_casing_lifecycle()
	_verify_ak47_hold_burst_ammo_duration_and_slowdown()
	_verify_removed_ak47_runtime_bridges()
	_verify_base_pistol_delayed_fire_runtime()
	_verify_pistol_delayed_fire_uses_latest_player_position()
	_verify_base_pistol_empty_click_reloads_full_magazine()
	_verify_base_pistol_uses_input_edges_after_switch()
	_verify_pistol_side_wall_bounce()
	_verify_commando_pistol_ammo_empty_and_instant_fire()
	_verify_weapon_hit_status_profiles()
	_verify_pistol_headshot_legshot_status_and_gauge()
	_verify_pistol_hit_gauge_result_handoff()
	_verify_projectile_hitbox_profiles()
	_verify_lingering_field_runtime()
	_verify_fire_support_call_lifecycle()
	_verify_bowling_trap_capture_launch_lifecycle()
	_verify_bowling_trap_round_carryover()
	_verify_suicide_drone_direct_control_lifecycle()
	_verify_suicide_drone_ball_boost_and_boss_restore()
	_verify_removed_suicide_drone_lingering_bridges()
	_verify_non_fire_inputs_do_not_spawn_vfx()
	_verify_serve_wait_fire_suppression_requires_release()
	_verify_cooldown_and_switch_suppression_do_not_spend_or_spawn()
	_verify_firearm_fx_host_activation_does_not_emit_stale_particles()
	_verify_stage1_renderer_context_reader()

	LanguageSettings.set_language(original_language)
	if _failures.is_empty():
		print("commando_firearm_runtime_vfx_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_successful_fire_spawns_visible_runtime() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var config: Dictionary = _fire_config()
	var deps: Dictionary = setup.get("deps", {})
	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(result.get("fired", false)), "ready bazooka shot should report fired")
	_expect(int(result.get("ammo_current", -1)) == 3, "bazooka shot should spend one of the Python 4 rockets")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "bazooka should keep firing state while rockets remain")
	_expect(is_equal_approx(float(result.get("cooldown_frames", 0.0)), 120.0), "bazooka should start the Python 120-frame internal cooldown")
	_expect(is_equal_approx(float(result.get("control_lock_frames", 0.0)), 30.0), "bazooka should expose the Python 30-frame control lock")
	_expect(is_equal_approx(float(result.get("muzzle_flash_frames", 0.0)), 5.0), "bazooka should expose the Python 5-frame muzzle flash timer")
	_expect(bool(runtime.is_player_control_locked()), "bazooka firing should lock player control during afterdelay")
	var audio: Object = setup.get("audio", null)
	_expect(_get_array(audio.fire_calls).size() == 1 and str(audio.fire_calls[0]) == "bazooka", "successful firearm shot should trigger a fire audio cue")

	var draw_context: Dictionary = runtime.get_actor_draw_context()
	var projectiles: Array = _get_array(draw_context.get("commando_firearm_projectiles", []))
	var muzzle_flashes: Array = _get_array(draw_context.get("commando_firearm_muzzle_flashes", []))
	_expect(projectiles.size() == 1, "successful firearm shot should create one projectile draw entry")
	_expect(muzzle_flashes.size() == 1, "successful firearm shot should create a muzzle flash")
	var first_projectile: Dictionary = _get_dict(projectiles[0])
	var first_pos: Vector2 = _get_vector2(first_projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var first_velocity: Vector2 = _get_vector2(first_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(first_pos.x, 433.5) and is_equal_approx(first_pos.y, 625.0), "bazooka rocket should spawn from the authored launcher muzzle tip")
	_expect(is_equal_approx(first_velocity.x, 0.0) and is_equal_approx(first_velocity.y, -3.0), "bazooka rocket should launch vertically at Python initial speed 3")
	_expect(is_equal_approx(float(first_projectile.get("explosion_radius", 0.0)), CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS), "bazooka projectile should carry the configured explosion radius")
	var fire_sheet_state: Dictionary = _get_dict(draw_context.get("commando_firearm_weapon_fire_sheet_state", {}))
	_expect(is_equal_approx(float(fire_sheet_state.get("timer_frames", 0.0)), 37.5), "bazooka firing sheet should start at F3 so the launch pose matches the rocket spawn")
	runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var moved_projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(moved_projectiles.size() == 1, "projectile should remain alive after one effect frame")
	var moved_projectile: Dictionary = _get_dict(moved_projectiles[0])
	var moved_pos: Vector2 = _get_vector2(moved_projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	_expect(moved_pos.y < first_pos.y, "bazooka projectile should travel toward the boss")
	var moved_velocity: Vector2 = _get_vector2(moved_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(moved_velocity.length(), 3.8), "bazooka rocket should accelerate by 0.8 on the first frame")
	_expect(_get_array(moved_projectile.get("smoke_trail", [])).size() >= 1, "bazooka rocket should leave smoke trail points")

	var saw_impact_flash := false
	for i in range(90):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		var frame_context: Dictionary = runtime.get_actor_draw_context()
		if (
			_get_array(frame_context.get("commando_firearm_projectiles", [])).is_empty()
			and not _get_array(frame_context.get("commando_firearm_impact_flashes", [])).is_empty()
		):
			saw_impact_flash = true
			break
	var settled_context: Dictionary = runtime.get_actor_draw_context()
	_expect(_get_array(settled_context.get("commando_firearm_projectiles", [])).is_empty(), "expired projectile should clean up")
	_expect(saw_impact_flash, "projectile cleanup should leave an impact flash before it fades")
	var hit_events: Array = _get_array(runtime.get_recent_hit_events())
	_expect(hit_events.size() == 1, "target impact should record one Commando firearm hit event")
	_expect(str(_get_dict(hit_events[0]).get("weapon_id", "")) == "bazooka", "hit event should preserve weapon id")
	var feedback: Object = setup.get("feedback", null)
	var impact_effects: Object = setup.get("impact_effects", null)
	var ball_effects: Object = setup.get("ball_effects", null)
	var animation_state: Object = setup.get("animation_state", null)
	var status_effect_state: Object = setup.get("status_effect_state", null)
	_expect(feedback.shake_calls >= 2 and _has_bazooka_explosion_shake(feedback), "target bazooka explosion should trigger per-hit feedback and a visible half-strength grenade screen shake")
	_expect(_get_array(impact_effects.hits).size() == 1, "target impact should spawn shared impact particles")
	_expect(_get_array(ball_effects.pulses).size() == 1 and str(_get_dict(ball_effects.pulses[0]).get("kind", "")) == "commando_bazooka", "target impact should register a ball hit pulse")
	_expect(animation_state.boss_hit_calls == 1 and bool(animation_state.last_has_hit_texture), "target impact should trigger boss hit animation")
	_expect(_get_array(audio.impact_calls).size() == 1 and str(audio.impact_calls[0]) == "bazooka", "target impact should trigger an impact audio cue")
	var bazooka_status_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_bazooka"))
	_expect(bazooka_status_calls.size() == 1, "target bazooka impact should apply one shared boss status")
	_expect(str(_get_dict(bazooka_status_calls[0]).get("status_id", "")) == "stun", "bazooka impact should apply boss stun")
	_expect(is_equal_approx(float(_get_dict(bazooka_status_calls[0]).get("duration_frames", 0.0)), 90.0), "bazooka stun should match Python 1.5s duration")
	var bazooka_status_data: Dictionary = _get_dict(_get_dict(bazooka_status_calls[0]).get("data", {}))
	_expect(is_equal_approx(abs(float(bazooka_status_data.get("knockback_vel", 0.0))), 40.0), "bazooka stun should start with the Python 40px knockback velocity")
	_expect(is_equal_approx(float(bazooka_status_data.get("knockback_frames", 0.0)), 18.0), "bazooka knockback motion should end before the full stun duration")
	_expect(is_equal_approx(float(bazooka_status_data.get("knockback_decay_per_frame", 0.0)), 0.85), "bazooka knockback motion should decay like the Python boss knockback velocity")
	_expect(int(_get_dict(_get_dict(hit_events[0]).get("result", {})).get("damage_units", 0)) == 2, "bazooka hit event should preserve boss-health damage metadata")


func _verify_bazooka_wall_impact_detonates_without_boss_contact() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	config["boss_pos"] = Vector2(620.0, 62.0)
	runtime.projectiles.append({
		"id": 9001,
		"weapon_id": "bazooka",
		"kind": "rocket",
		"pos": Vector2(40.0, 35.0),
		"prev_pos": Vector2(40.0, 55.0),
		"velocity": Vector2(0.0, -20.0),
		"speed": 20.0,
		"radius": 9.5,
		"impact_radius": 46.0,
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
		"life_frames": 30.0,
		"target": Vector2(40.0, 80.0),
		"color": Color(1.0, 0.46, 0.18),
		"secondary": Color(1.0, 0.88, 0.38),
	})
	var result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	_expect(bool(result.get("commando_firearm_environment_impact", false)), "bazooka should detonate on the wall even when the boss is outside the blast radius")
	_expect(str(result.get("commando_firearm_environment_impact_reason", "")) == "wall", "bazooka wall detonation should expose the wall impact reason")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "bazooka wall detonation should consume the rocket")
	var flashes: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_impact_flashes", []))
	_expect(flashes.size() == 1, "bazooka wall detonation should spawn an explosion flash")
	_expect(is_equal_approx(_get_vector2(_get_dict(flashes[0]).get("pos", Vector2.ZERO), Vector2.ZERO).y, 20.0), "bazooka wall detonation should clamp the flash to the back wall")
	var audio: Object = setup.get("audio", null)
	var impact_effects: Object = setup.get("impact_effects", null)
	var feedback: Object = setup.get("feedback", null)
	var animation_state: Object = setup.get("animation_state", null)
	var status_effect_state: Object = setup.get("status_effect_state", null)
	_expect(_get_array(audio.impact_calls) == ["bazooka"], "bazooka wall detonation should play the impact/explosion cue")
	_expect(_get_array(impact_effects.hits).size() == 1, "bazooka wall detonation should spawn shared explosion particles")
	_expect(feedback.shake_calls >= 2 and _has_bazooka_explosion_shake(feedback), "bazooka wall detonation should trigger per-hit feedback and a visible half-strength grenade screen shake")
	_expect(animation_state.boss_hit_calls == 0, "bazooka wall detonation outside radius should not trigger boss hit animation")
	_expect(_get_array(status_effect_state.get_calls_for_source("commando_firearm_bazooka")).is_empty(), "bazooka wall detonation outside radius should not apply boss stun")
	_expect(_get_array(runtime.get_recent_hit_events()).is_empty(), "bazooka wall detonation outside radius should not record a boss hit event")


func _verify_bazooka_edge_only_wall_blast_does_not_stun() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	config["boss_pos"] = Vector2(350.0, 0.0)
	config["boss_paddle_width"] = 100.0
	config["boss_hitbox_height"] = 40.0
	runtime.projectiles.append({
		"id": 9002,
		"weapon_id": "bazooka",
		"kind": "rocket",
		"pos": Vector2(200.0, 18.0),
		"prev_pos": Vector2(200.0, 38.0),
		"velocity": Vector2(0.0, -20.0),
		"speed": 20.0,
		"radius": 9.5,
		"impact_radius": 46.0,
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
		"life_frames": 30.0,
		"target": Vector2(200.0, 80.0),
		"color": Color(1.0, 0.46, 0.18),
		"secondary": Color(1.0, 0.88, 0.38),
	})
	var result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	_expect(bool(result.get("commando_firearm_environment_impact", false)), "bazooka edge-only wall blast should resolve as an environment impact")
	_expect(str(result.get("commando_firearm_environment_impact_reason", "")) == "wall", "bazooka edge-only wall blast should preserve the wall reason")
	var status_effect_state: Object = setup.get("status_effect_state", null)
	var animation_state: Object = setup.get("animation_state", null)
	_expect(_get_array(status_effect_state.get_calls_for_source("commando_firearm_bazooka")).is_empty(), "bazooka edge-only wall blast should not apply boss stun")
	_expect(animation_state.boss_hit_calls == 0, "bazooka edge-only wall blast should not trigger boss hit animation")
	_expect(_get_array(runtime.get_recent_hit_events()).is_empty(), "bazooka edge-only wall blast should not record a boss hit event")


func _verify_fire_support_edge_only_blast_does_not_stun() -> void:
	var setup: Dictionary = _build_setup("fire_support")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	config["boss_pos"] = Vector2(350.0, 50.0)
	config["boss_paddle_width"] = 100.0
	config["boss_hitbox_height"] = 40.0
	runtime.projectiles.append({
		"id": 9101,
		"weapon_id": "fire_support",
		"kind": "support",
		"pos": Vector2(200.0, 70.0),
		"prev_pos": Vector2(200.0, 60.0),
		"velocity": Vector2.ZERO,
		"radius": 7.0,
		"life_frames": 120.0,
		"target": Vector2(200.0, 70.0),
		"target_y": 70.0,
		"color": Color(1.0, 0.34, 0.16),
		"secondary": Color(1.0, 0.82, 0.25),
	})
	runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var status_effect_state: Object = setup.get("status_effect_state", null)
	var animation_state: Object = setup.get("animation_state", null)
	_expect(_get_array(status_effect_state.get_calls_for_source("commando_firearm_fire_support")).is_empty(), "fire support edge-only blast should not apply boss stun")
	_expect(animation_state.boss_hit_calls == 0, "fire support edge-only blast should not trigger boss hit animation")
	_expect(_get_array(runtime.get_recent_hit_events()).is_empty(), "fire support edge-only blast should not record a boss hit event")


func _verify_suicide_drone_edge_only_blast_does_not_stun() -> void:
	var setup: Dictionary = _build_setup("suicide_drone")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	config["boss_pos"] = Vector2(350.0, 50.0)
	config["boss_paddle_width"] = 100.0
	config["boss_hitbox_height"] = 40.0
	var projectile := {
		"id": 9102,
		"weapon_id": "suicide_drone",
		"kind": "drone",
		"pos": Vector2(205.0, 70.0),
		"prev_pos": Vector2(205.0, 70.0),
		"velocity": Vector2.ZERO,
		"radius": 24.0,
		"life_frames": 120.0,
		"color": Color(1.0, 0.42, 0.18),
		"secondary": Color(0.45, 0.86, 1.0),
	}
	runtime.projectiles.append(projectile.duplicate(true))
	var result: Dictionary = CommandoFirearmSuicideDroneState.detonate_runtime_projectile_at_index(
		runtime.projectiles,
		0,
		runtime.impact_flashes,
		runtime,
		projectile,
		"manual",
		config,
		deps,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		CommandoFirearmRuntime.FIELD_WIDTH,
		CommandoFirearmRuntime.SUICIDE_DRONE_COOLDOWN_FRAMES,
		CommandoFirearmRuntime.SUICIDE_DRONE_BALL_SPEED_MULTIPLIER,
		CommandoFirearmRuntime.SUICIDE_DRONE_BALL_FAN_DEGREES,
		float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES),
		CommandoFirearmRuntime.FLASH_LIMIT
	)
	_expect(bool(result.get("commando_suicide_drone_detonated", false)), "suicide drone edge-only blast should still detonate")
	_expect(not bool(result.get("commando_suicide_drone_hit_boss", true)), "suicide drone edge-only blast should report no boss hit")
	var status_effect_state: Object = setup.get("status_effect_state", null)
	var animation_state: Object = setup.get("animation_state", null)
	var active_item_runtime: Object = setup.get("active_item_runtime", null)
	_expect(_get_array(status_effect_state.get_calls_for_source("commando_firearm_suicide_drone")).is_empty(), "suicide drone edge-only blast should not apply boss status")
	_expect(_get_array(active_item_runtime.molotov_fire_zone_calls).size() == 1, "suicide drone edge-only blast should still spawn the molotov fire-zone residue")
	_expect(animation_state.boss_hit_calls == 0, "suicide drone edge-only blast should not trigger boss hit animation")
	_expect(_get_array(runtime.get_recent_hit_events()).is_empty(), "suicide drone edge-only blast should not record a boss hit event")


func _verify_net_gun_ammo_rope_capture_and_break() -> void:
	var setup: Dictionary = _build_setup("net_gun")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var config: Dictionary = _fire_config()
	var deps: Dictionary = setup.get("deps", {})
	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(result.get("fired", false)), "ready net gun shot should report fired")
	_expect(int(result.get("ammo_current", -1)) == 3, "net gun should spend one of the tuned 4 harpoons")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "net gun should remain fire-capable while harpoons remain")
	_expect(is_equal_approx(float(result.get("cooldown_frames", 0.0)), 120.0), "net gun should start the Python 120-frame internal cooldown")
	_expect(is_equal_approx(float(result.get("control_lock_frames", 0.0)), 30.0), "net gun should expose the Python 30-frame control lock")
	_expect(is_equal_approx(float(result.get("throw_pose_frames", 0.0)), 30.0), "net gun should expose the Python throw-pose timer")
	_expect(is_equal_approx(float(result.get("harpoon_flash_frames", 0.0)), 6.0), "net gun should expose the Python harpoon flash timer")
	_expect(bool(runtime.is_player_control_locked()), "net gun firing should lock player control during afterdelay")

	var initial_projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(initial_projectiles.size() == 1, "net gun shot should create one harpoon projectile")
	var projectile: Dictionary = _get_dict(initial_projectiles[0])
	_expect(str(projectile.get("kind", "")) == "net", "net gun projectile should expose net kind")
	_expect(is_equal_approx(_get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO).length(), 18.0), "net gun harpoon should use the Python 18px/frame speed")
	var projectile_pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var rope_origin: Vector2 = _get_vector2(projectile.get("origin", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(projectile_pos.x, 405.5) and is_equal_approx(projectile_pos.y, 638.0), "net gun harpoon should spawn from the authored muzzle tip")
	_expect(is_equal_approx(rope_origin.x, 405.5) and is_equal_approx(rope_origin.y, 638.0), "net gun rope origin should attach to the authored muzzle tip")

	runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var moved_projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(moved_projectiles.size() == 1, "net gun harpoon should stay alive after one frame")
	var moved_projectile: Dictionary = _get_dict(moved_projectiles[0])
	_expect(_get_array(moved_projectile.get("rope_points", [])).size() >= 1, "net gun harpoon should leave rope trail points")

	var captured := false
	for _i in range(60):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		var fields: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
		if not fields.is_empty():
			captured = true
			break
	_expect(captured, "net gun harpoon should deploy a net field on target capture")
	var net_fields: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
	var net_field: Dictionary = _get_dict(net_fields[0])
	_expect(str(net_field.get("kind", "")) == "net_field", "net gun capture should expose a net field")
	_expect(bool(net_field.get("hooked_player", false)), "successful net should hook the player rope")
	_expect(not bool(net_field.get("dissolve", false)), "successful net should not start as dissolve")
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 1.0), "hooked net should preserve normal Commando movement speed")

	var moved_hook_config: Dictionary = config.duplicate(true)
	moved_hook_config["player_pos"] = Vector2(420.0, 654.0)
	runtime.update_effects(1.0, Time.get_ticks_msec(), moved_hook_config, deps)
	var moved_fields: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
	var moved_field: Dictionary = _get_dict(moved_fields[0])
	var moved_origin: Vector2 = _get_vector2(moved_field.get("origin", Vector2.ZERO), Vector2.ZERO)
	var moved_expected_origin: Vector2 = _expected_net_gun_aim_origin(moved_hook_config)
	_expect(moved_origin.is_equal_approx(moved_expected_origin), "hooked net rope origin should follow the current player muzzle after movement")
	_expect(not moved_origin.is_equal_approx(rope_origin), "hooked net rope origin should not stay pinned to the firing-frame player position")

	var clamp_config: Dictionary = config.duplicate(true)
	clamp_config["boss_pos"] = Vector2(620.0, 62.0)
	var clamp_result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), clamp_config, deps)
	_expect(bool(clamp_result.get("commando_net_gun_boss_clamped", false)), "active net should clamp boss X inside the net")
	_expect(_get_vector2(clamp_result.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x < 500.0, "net boss clamp should move an escaped boss back into the net")

	var dash_context: Dictionary = moved_hook_config.duplicate(true)
	dash_context["player_pos"] = Vector2(500.0, 654.0)
	dash_context["dash_snapshot"] = {"active": true}
	runtime.update_effects(1.0, Time.get_ticks_msec(), dash_context, deps)
	var broken_fields: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
	var broken_field: Dictionary = _get_dict(broken_fields[0])
	_expect(bool(broken_field.get("dissolve", false)) and bool(broken_field.get("rope_broken", false)), "dash start should break the net rope and dissolve the field")
	_expect(
		_get_vector2(broken_field.get("origin", Vector2.ZERO), Vector2.ZERO).is_equal_approx(_expected_net_gun_aim_origin(dash_context)),
		"breaking net rope origin should use the current player muzzle at dash break"
	)
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 1.0), "rope break should keep net movement neutral")

	var miss_setup: Dictionary = _build_setup("net_gun")
	var miss_runtime: Object = miss_setup.get("runtime", null)
	var miss_projectile: Dictionary = _direct_projectile("net_gun", Vector2(60.0, 120.0), Vector2(-18.0, 0.0))
	miss_projectile["target"] = Vector2(40.0, 120.0)
	miss_runtime._spawn_lingering_effect(
		"net_gun",
		CommandoFirearmLingeringEffectState.build_net_dissolve_projectile(miss_projectile),
		config
	)
	var miss_fields: Array = _get_array(miss_runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
	var miss_field: Dictionary = _get_dict(miss_fields[0])
	_expect(bool(miss_field.get("dissolve", false)), "missed net shot should deploy a dissolve net")
	_expect(is_equal_approx(float(miss_field.get("timer_frames", 0.0)), 21.0), "missed net dissolve should use the Python 0.35s duration")


func _verify_ak47_shell_casing_lifecycle() -> void:
	var setup: Dictionary = _build_setup("ak47")
	var runtime: Object = setup.get("runtime", null)
	var config: Dictionary = _fire_config()
	var deps: Dictionary = setup.get("deps", {})
	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(result.get("fired", false)), "AK-47 shot should fire for shell casing smoke")
	var initial_context: Dictionary = runtime.get_actor_draw_context()
	var shells: Array = _get_array(initial_context.get("commando_firearm_shell_casings", []))
	_expect(shells.size() == 1, "AK-47 shot should spawn one shell casing draw entry")
	var shell: Dictionary = _get_dict(shells[0])
	_expect(str(shell.get("weapon_id", "")) == "ak47", "AK-47 shell casing should preserve weapon id")
	_expect(float(shell.get("lifetime_frames", 0.0)) == 180.0, "AK-47 shell casing should use the Python 3s lifetime")
	var start_pos: Vector2 = _get_vector2(shell.get("pos", Vector2.ZERO), Vector2.ZERO)
	runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var moved_shells: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_shell_casings", []))
	_expect(moved_shells.size() == 1, "AK-47 shell casing should stay visible after one frame")
	var moved_shell: Dictionary = _get_dict(moved_shells[0])
	var moved_pos: Vector2 = _get_vector2(moved_shell.get("pos", Vector2.ZERO), Vector2.ZERO)
	_expect(moved_pos.x > start_pos.x, "AK-47 shell casing should eject to the right")
	_expect(float(moved_shell.get("lifetime_frames", 0.0)) < float(shell.get("lifetime_frames", 0.0)), "AK-47 shell casing lifetime should tick down")
	for _i in range(190):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_shell_casings", [])).is_empty(), "AK-47 shell casing should clean up after its lifetime")


func _verify_ak47_hold_burst_ammo_duration_and_slowdown() -> void:
	var setup: Dictionary = _build_setup("ak47")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var audio: Object = setup.get("audio", null)
	var config: Dictionary = _fire_config()
	var deps: Dictionary = setup.get("deps", {})

	var idle: Dictionary = runtime.update_input({"action_pressed": false}, 500.0, config, deps)
	_expect(idle.is_empty(), "AK-47 should stay idle when selected but not firing")
	_expect(is_equal_approx(float(controller.get_current_weapon_data().get("duration_frames", 0.0)), 1800.0), "AK-47 durability should not tick down while merely selected")

	var first: Dictionary = runtime.update_input({"action_pressed": true, "action_just_pressed": true}, 500.0, config, deps)
	_expect(bool(first.get("fired", false)), "AK-47 first trigger press should fire immediately")
	_expect(int(first.get("ammo_current", -1)) == 89, "AK-47 first shot should spend one of 90 bullets")
	_expect(is_equal_approx(float(first.get("duration_frames", 0.0)), 1799.0), "AK-47 active durability should tick while the trigger is held")
	_expect(is_equal_approx(float(first.get("movement_speed_multiplier", 1.0)), 0.5), "AK-47 held fire should expose the Python 50% movement debuff")
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 0.5), "AK-47 runtime should keep movement debuff while trigger is held")
	_expect(is_equal_approx(float(first.get("recoil_accumulation", 0.0)), 0.03), "AK-47 first shot should add the Python 0.03 recoil spread")
	var first_context: Dictionary = runtime.get_actor_draw_context()
	var first_projectiles: Array = _get_array(first_context.get("commando_firearm_projectiles", []))
	_expect(first_projectiles.size() == 1, "AK-47 first press should spawn one bullet")
	var first_projectile: Dictionary = _get_dict(first_projectiles[0])
	var first_velocity: Vector2 = _get_vector2(first_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(first_velocity.length(), 16.0), "AK-47 bullet speed should match the Python 16px/frame value")
	_expect(abs(_angle_delta(first_velocity.angle(), _ak47_base_aim_angle(config))) <= 0.1501, "AK-47 first bullet should randomize angle within the Python base 0.15 rad spread")
	_expect(is_equal_approx(float(first_projectile.get("max_life_frames", 0.0)), 60.0), "AK-47 bullet lifetime should match the Python 60-frame value")
	_expect(_get_array(first_context.get("commando_firearm_shell_casings", [])).size() == 1, "AK-47 first shot should eject one casing")
	_expect(_get_array(audio.fire_calls) == ["ak47"], "AK-47 first shot should route one rapid-fire cue")

	for _i in range(5):
		var waiting: Dictionary = runtime.update_input({"action_pressed": true, "action_just_pressed": false}, 500.0, config, deps)
		_expect(not bool(waiting.get("fired", false)), "AK-47 should wait for the 6-frame fire interval between burst shots")
	var second: Dictionary = runtime.update_input({"action_pressed": true, "action_just_pressed": false}, 500.0, config, deps)
	_expect(bool(second.get("fired", false)), "AK-47 held trigger should fire the second burst shot after 6 frames")
	_expect(int(second.get("ammo_current", -1)) == 88, "AK-47 second burst shot should spend another bullet")
	_expect(int(second.get("burst_shots_remaining", -1)) == 0, "AK-47 initial burst should consume its two-shot budget")
	_expect(is_equal_approx(float(second.get("recoil_accumulation", 0.0)), 0.06), "AK-47 second shot should keep accumulating recoil spread")
	var second_projectile: Dictionary = _get_dict(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))[1])
	var second_velocity: Vector2 = _get_vector2(second_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(abs(_angle_delta(second_velocity.angle(), _ak47_base_aim_angle(config))) <= 0.1801, "AK-47 second bullet should randomize angle within base spread plus first-shot recoil")

	var third: Dictionary = {}
	for _i in range(6):
		third = runtime.update_input({"action_pressed": true, "action_just_pressed": false}, 500.0, config, deps)
	_expect(bool(third.get("fired", false)), "AK-47 held trigger should continue into automatic fire after the burst")
	_expect(int(third.get("ammo_current", -1)) == 87, "AK-47 automatic fire should continue spending ammo")
	_expect(_get_array(audio.fire_calls).size() == 3, "AK-47 three shots should play three rapid-fire cues")
	_expect(is_equal_approx(float(third.get("recoil_accumulation", 0.0)), 0.09), "AK-47 automatic fire should keep accumulating recoil spread")
	var held_context: Dictionary = runtime.get_actor_draw_context()
	_expect(_get_array(held_context.get("commando_firearm_projectiles", [])).size() == 3, "AK-47 burst plus auto-fire should leave three active bullets before effect update")
	var third_projectile: Dictionary = _get_dict(_get_array(held_context.get("commando_firearm_projectiles", []))[2])
	var third_velocity: Vector2 = _get_vector2(third_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(abs(_angle_delta(third_velocity.angle(), _ak47_base_aim_angle(config))) <= 0.2101, "AK-47 third bullet should randomize angle within base spread plus accumulated recoil")
	_expect(_get_array(held_context.get("commando_firearm_shell_casings", [])).size() == 3, "AK-47 burst plus auto-fire should leave three shell casings")

	runtime.update_input({"action_pressed": false, "action_just_released": true}, 500.0, config, deps)
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 1.0), "AK-47 release should clear the movement debuff")
	var weapon_data: Dictionary = controller.get_current_weapon_data()
	_expect(int(weapon_data.get("ammo_current", -1)) == 87, "AK-47 controller ammo should stay synced after held fire")
	_expect(float(weapon_data.get("duration_frames", 1800.0)) < 1800.0, "AK-47 controller should expose consumed durability")
	_expect(str(weapon_data.get("ammo_text", "")).begins_with("탄약 87/90 · 내구 "), "AK-47 ammo text should include bullets and durability")


func _verify_removed_ak47_runtime_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_consume_ak47_duration",
		"_trigger_ak47_cooldown",
	]:
		_expect(runtime_source.find("func %s(" % bridge_name) == -1, "runtime should not keep AK-47 bridge %s" % bridge_name)


func _verify_weapon_hit_status_profiles() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var status_effect_state: Object = setup.get("status_effect_state", null)
	var config: Dictionary = _fire_config()

	runtime._register_projectile_hit(_direct_projectile("ak47", Vector2(320.0, 82.0), Vector2(24.0, -8.0)), config, deps)
	var ak_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_ak47"))
	_expect(ak_calls.size() == 1, "AK-47 hit should apply one shared boss status")
	_expect(str(_get_dict(ak_calls[0]).get("status_id", "")) == "stun", "AK-47 hit should apply short boss stun")
	_expect(is_equal_approx(float(_get_dict(ak_calls[0]).get("duration_frames", 0.0)), 12.0), "AK-47 stun should match the 0.2s tuning")
	var ak_status_data: Dictionary = _get_dict(_get_dict(ak_calls[0]).get("data", {}))
	var expected_ak_knockback: float = CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_POWER + 24.0 * CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_VELOCITY_SCALE
	_expect(is_equal_approx(float(ak_status_data.get("knockback_vel", 0.0)), expected_ak_knockback), "AK-47 hit should apply a small natural boss knockback")
	_expect(bool(ak_status_data.get("knockback_active", false)), "AK-47 stun should expose a short moving knockback channel")
	_expect(is_equal_approx(float(ak_status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_FRAMES), "AK-47 knockback should end before the full stun duration")
	_expect(is_equal_approx(float(ak_status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_DECAY_PER_FRAME), "AK-47 knockback should decay quickly for a natural bullet nudge")
	var ak_real_status := StatusEffectState.new()
	var ak_motion_runtime := CommandoFirearmRuntime.new()
	ak_motion_runtime._register_projectile_hit(_direct_projectile("ak47", Vector2(320.0, 82.0), Vector2(24.0, -8.0)), config, {"status_effect_state": ak_real_status})
	var ak_ai_context: Dictionary = ak_real_status.get_boss_ai_context()
	var ak_stunned_motion: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(328.0, 62.0), -2.5, ak_ai_context)
	_expect(is_equal_approx(float(ak_stunned_motion.get("boss_vel", 999.0)), expected_ak_knockback), "AK-47 stun should replace previous boss movement with a short bullet nudge")
	_expect(is_equal_approx(_get_vector2(ak_stunned_motion.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x, 328.0 + expected_ak_knockback), "AK-47 stun should nudge boss x position on the first knockback frame")
	for _ak_i in range(int(CommandoFirearmRuntime.AK47_BOSS_KNOCKBACK_FRAMES)):
		ak_real_status.update(1.0)
	var ak_settled_context: Dictionary = ak_real_status.get_boss_ai_context()
	var ak_settled_motion: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(328.0, 62.0), -2.5, ak_settled_context)
	_expect(is_equal_approx(float(ak_settled_motion.get("boss_vel", 999.0)), 0.0), "AK-47 stun should stop the bullet nudge before the stun expires")
	_expect(is_equal_approx(_get_vector2(ak_settled_motion.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x, 328.0), "AK-47 stun should hold position after the short knockback window")

	runtime._register_projectile_hit(_direct_projectile("net_gun", Vector2(350.0, 82.0), Vector2(0.0, -10.0)), config, deps)
	var net_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_net_gun"))
	_expect(net_calls.is_empty(), "net gun hit should not apply a boss slow status")

	runtime._register_projectile_hit(_direct_projectile("suicide_drone", Vector2(360.0, 82.0), Vector2(8.0, -8.0)), config, deps)
	var drone_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_suicide_drone"))
	_expect(drone_calls.size() == 1, "suicide drone hit should apply the original 0.8s boss stun with light knockback")
	_expect(str(_get_dict(drone_calls[0]).get("status_id", "")) == "stun", "suicide drone should apply boss stun")
	var drone_status_data: Dictionary = _get_dict(_get_dict(drone_calls[0]).get("data", {}))
	_expect(is_equal_approx(abs(float(drone_status_data.get("knockback_vel", 0.0))), CommandoFirearmRuntime.SUICIDE_DRONE_KNOCKBACK_POWER), "suicide drone explosion should nudge the boss with the light drone knockback")
	_expect(bool(drone_status_data.get("knockback_active", false)), "suicide drone stun should expose a short knockback motion")
	_expect(is_equal_approx(float(drone_status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.SUICIDE_DRONE_KNOCKBACK_FRAMES), "suicide drone knockback should use the shared short motion window")
	_expect(is_equal_approx(float(drone_status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.SUICIDE_DRONE_KNOCKBACK_DECAY_PER_FRAME), "suicide drone knockback should decay through the shared fire-event feel")

	var support_projectile: Dictionary = _direct_projectile("fire_support", Vector2(360.0, 82.0), Vector2(0.0, 12.0))
	support_projectile["kind"] = "support"
	CommandoFirearmImpactFlashResolver.append_flash(
		runtime.impact_flashes,
		support_projectile,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
		CommandoFirearmRuntime.FLASH_LIMIT
	)
	runtime._register_projectile_hit(support_projectile, config, deps)
	var support_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_fire_support"))
	_expect(support_calls.size() == 1, "fire support bomb should apply one shared boss stun")
	var support_call: Dictionary = _get_dict(support_calls[0])
	_expect(is_equal_approx(float(support_call.get("duration_frames", 0.0)), ActiveItemThrowController.GRENADE_BOSS_STUN_FRAMES), "fire support bomb stun should match grenade stun duration")
	var support_status_data: Dictionary = _get_dict(support_call.get("data", {}))
	_expect(is_equal_approx(abs(float(support_status_data.get("knockback_vel", 0.0))), ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_POWER), "fire support bomb knockback distance should match grenade knockback power")
	_expect(is_equal_approx(float(support_status_data.get("knockback_frames", 0.0)), ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_FRAMES), "fire support bomb knockback window should match grenade knockback window")
	_expect(is_equal_approx(float(support_status_data.get("knockback_decay_per_frame", 0.0)), ActiveItemThrowController.GRENADE_BOSS_KNOCKBACK_DECAY), "fire support bomb knockback decay should match grenade decay")
	var support_flash: Dictionary = _find_impact_flash(runtime, "fire_support")
	_expect(str(support_flash.get("kind", "")) == "grenade_explosion", "fire support bomb should render through the grenade explosion effect")
	_expect(str(support_flash.get("explosion_style", "")) == GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE, "fire support bomb should use the high-quality airstrike explosion style")
	_expect(int(support_flash.get("texture_layer_count", 0)) == GrenadeExplosionDrawer.FIRE_SUPPORT_TEXTURE_LAYER_COUNT, "fire support bomb should expose the airstrike texture layer budget")
	_expect(is_equal_approx(float(support_flash.get("radius", 0.0)), ActiveItemThrowController.GRENADE_EXPLOSION_RADIUS), "fire support bomb explosion radius should match grenade radius")
	_expect(is_equal_approx(float(support_flash.get("max_timer_frames", 0.0)), float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES)), "fire support bomb explosion visual duration should match airstrike duration")
	_expect(not _has_lingering_effect_for_weapon(runtime, "fire_support"), "fire support should not add an extra blast-field residue over the grenade explosion effect")

	var recent_events: Array = _get_array(runtime.get_recent_hit_events())
	_expect(recent_events.size() == 4, "direct weapon hit profile check should record four hit events")
	_expect(int(_get_dict(_get_dict(recent_events[0]).get("result", {})).get("damage_units", -1)) == 0, "AK-47 hit metadata should not claim immediate health damage")


func _verify_base_pistol_delayed_fire_runtime() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var audio := FakeAudio.new()
	var deps := {
		"commando_weapon_controller": controller,
		"skill_state": state,
		"skill_config": config,
		"audio": audio,
	}
	var result: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		100.0,
		_fire_config(),
		deps
	)
	_expect(bool(result.get("shot_queued", false)), "base pistol should queue the original draw/ready animation on a fresh press")
	_expect(not bool(result.get("fired", false)), "base pistol should not spawn the bullet on the input frame")
	_expect(str(result.get("weapon_id", "")) == "pistol", "base pistol should preserve the save-compatible pistol id")
	_expect(is_equal_approx(float(result.get("special_gauge", 0.0)), 100.0), "base pistol should not spend special gauge")
	_expect(bool(runtime.is_player_control_locked()), "base pistol should apply the original pistol afterdelay lock while drawing")
	_expect(int(result.get("ammo_current", -1)) == 4, "base pistol should spend one round from the five-round magazine when queued")
	_expect(audio.pistol_ready_calls == 1, "base pistol queued shot should play the gun-ready cue before firing")
	var projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(projectiles.is_empty(), "base pistol should wait through the draw/aim animation before creating a projectile")

	for _i in range(23):
		runtime.update_input({"action_pressed": false}, 100.0, _fire_config(), deps)
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "base pistol should still be aiming before the 24-frame release")
	var delayed_fire: Dictionary = runtime.update_input({"action_pressed": false}, 100.0, _fire_config(), deps)
	_expect(bool(delayed_fire.get("fired", false)), "base pistol should fire after the original 24-frame draw/aim delay")
	projectiles = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(projectiles.size() == 1, "base pistol should create one projectile after the delay")
	var projectile: Dictionary = _get_dict(projectiles[0])
	_expect(str(projectile.get("weapon_id", "")) == "pistol", "base pistol projectile should keep the base weapon id")
	_expect(str(projectile.get("kind", "")) == "bullet", "base pistol should use a clean bullet projectile")
	_expect(not bool(projectile.get("slingshot", false)), "base pistol projectile should not carry the removed slingshot marker")
	_expect(is_equal_approx(_get_vector2(projectile.get("velocity", Vector2.ZERO), Vector2.ZERO).length(), 25.0), "base pistol should use the fast pistol bullet speed")
	_expect(abs(float(projectile.get("angle_offset", 999.0))) <= PI / 12.0, "base pistol bullet should use the original ±15 degree spread")
	_expect(is_equal_approx(float(projectile.get("radius", 0.0)), 4.4), "base pistol bullet should stay smaller than the enhanced pistol round")
	_expect(_color_close(_get_color(projectile.get("color", Color.TRANSPARENT), Color.TRANSPARENT), Color(0.96, 0.82, 0.36)), "base pistol bullet should use the pistol brass color")
	var shells: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_shell_casings", []))
	_expect(shells.size() == 1 and str(_get_dict(shells[0]).get("weapon_id", "")) == "pistol", "base pistol should eject a pistol casing with the base id")
	_expect(_get_array(audio.fire_calls) == ["pistol"], "base pistol should route the gunshot cue only when the bullet spawns")

	var hit_runtime := CommandoFirearmRuntime.new()
	var status := FakeStatusEffectState.new()
	var hit_audio := FakeAudio.new()
	var hit_impact_effects := FakeImpactEffects.new()
	var hit_ball_effects := FakeBallEffects.new()
	var hit_feedback := FakeFeedback.new()
	var hit_animation := FakeAnimationState.new()
	var base_hit_projectile: Dictionary = _direct_projectile("pistol", Vector2(330.0, 82.0), Vector2(0.0, -25.0))
	base_hit_projectile["shot_roll"] = 0.99
	hit_runtime._register_projectile_hit(
		base_hit_projectile,
		_fire_config(),
		{
			"status_effect_state": status,
			"audio": hit_audio,
			"impact_effects": hit_impact_effects,
			"ball_effects": hit_ball_effects,
			"feedback": hit_feedback,
			"animation_state": hit_animation,
		}
	)
	var pistol_calls: Array = _get_array(status.get_calls_for_source("commando_firearm_pistol"))
	_expect(pistol_calls.size() == 1, "base pistol hit should apply the original pistol stun source")
	_expect(is_equal_approx(float(_get_dict(pistol_calls[0]).get("duration_frames", 0.0)), 42.0), "base pistol stun should match the requested 0.7-second tuning")
	var pistol_status_data: Dictionary = _get_dict(_get_dict(pistol_calls[0]).get("data", {}))
	_expect(is_equal_approx(abs(float(pistol_status_data.get("knockback_vel", 0.0))), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER), "base pistol normal stun should restore the original light knockback")
	_expect(bool(pistol_status_data.get("knockback_active", false)), "base pistol normal stun should expose a short knockback motion")
	_expect(is_equal_approx(float(pistol_status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_FRAMES), "base pistol normal knockback should use the original short motion window")
	_expect(is_equal_approx(float(pistol_status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME), "base pistol normal knockback should decay like the original boss stun drift")
	var hit_result: Dictionary = _get_dict(_get_dict(_get_array(hit_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(not hit_result.has("commando_firearm_slingshot_charge_level"), "base pistol hit should not emit slingshot charge metadata")
	_expect(is_equal_approx(float(hit_result.get("commando_firearm_special_gauge_gain", 0.0)), 30.0), "base pistol hit should use the original pistol gauge-gain lane")
	_expect(str(hit_result.get("pistol_hit_kind", "")) == "normal", "base pistol roll should share the original normal pistol hit lane")
	_expect(_get_array(hit_runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", [])).is_empty(), "normal base pistol hit should not spawn headshot/legshot feedback")
	_expect(_get_array(hit_impact_effects.hits).size() == 1, "base pistol hit should spawn shared impact particles")
	_expect(_get_array(hit_ball_effects.pulses).size() == 1 and str(_get_dict(hit_ball_effects.pulses[0]).get("kind", "")) == "commando_base_pistol", "base pistol hit should register a dedicated base-pistol ball pulse")
	_expect(hit_audio.impact_calls == ["pistol"], "base pistol hit should route a bullet impact cue through the base weapon id")
	_expect(hit_feedback.shake_calls == 1, "base pistol hit should still trigger shared screen feedback")
	_expect(hit_animation.boss_hit_calls == 1, "base pistol hit should still trigger the boss hit animation")


func _verify_pistol_delayed_fire_uses_latest_player_position() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var deps := {
		"commando_weapon_controller": controller,
		"skill_state": state,
		"skill_config": config,
	}
	var start_config: Dictionary = _fire_config()
	start_config["player_pos"] = Vector2(120.0, 654.0)
	var queue_result: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		100.0,
		start_config,
		deps
	)
	_expect(bool(queue_result.get("shot_queued", false)), "dash-position pistol smoke should queue a delayed pistol shot")
	var dash_config: Dictionary = _fire_config()
	dash_config["player_pos"] = Vector2(420.0, 654.0)
	dash_config["dash_snapshot"] = {"active": true, "direction": 1.0}
	for _i in range(23):
		runtime.update_input({"action_pressed": false}, 100.0, dash_config, deps)
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "dash-position pistol smoke should still wait before release")
	var delayed_fire: Dictionary = runtime.update_input({"action_pressed": false}, 100.0, dash_config, deps)
	_expect(bool(delayed_fire.get("fired", false)), "dash-position pistol smoke should fire after the draw delay")
	var projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(projectiles.size() == 1, "dash-position pistol smoke should create one delayed projectile")
	var projectile: Dictionary = _get_dict(projectiles[0])
	var projectile_pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(projectile_pos.x, 535.5), "delayed pistol bullet should spawn from the latest authored muzzle x after dash movement")
	_expect(is_equal_approx(projectile_pos.y, 638.0), "delayed pistol bullet should spawn from the authored pistol muzzle y")
	_expect(not is_equal_approx(projectile_pos.x, 235.5), "delayed pistol bullet should not stay anchored to the pre-dash player x")


func _verify_base_pistol_empty_click_reloads_full_magazine() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var audio := FakeAudio.new()
	var deps := {
		"commando_weapon_controller": controller,
		"skill_state": state,
		"skill_config": config,
		"audio": audio,
	}
	_expect(controller.unlock_permanent_weapon("net_gun", true), "base pistol reload setup should provide another firearm for switch-lock verification")
	_expect(controller.set_current_weapon("pistol"), "base pistol reload setup should return to the base pistol")
	for _i in range(5):
		_expect(bool(controller.consume_current_weapon_ammo(1)), "base pistol setup should be able to empty the five-round magazine")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 0, "base pistol setup should leave an empty magazine")
	var insufficient: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		149.0,
		_fire_config(),
		deps
	)
	_expect(str(insufficient.get("failure_reason", "")) == "pistol_reload_gauge_insufficient", "empty base pistol should need 150 gauge to reload from fire input")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 0, "failed empty-click reload should not add ammo")
	_expect(audio.pistol_reload_round_calls == 0, "failed empty-click reload should not play a round reload cue")
	var reload_result: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		150.0,
		_fire_config(),
		deps
	)
	_expect(bool(reload_result.get("reload_started", false)), "empty base pistol left-click should start a full magazine reload")
	_expect(not bool(reload_result.get("shot_queued", false)), "empty base pistol reload click should not also queue a shot")
	_expect(int(reload_result.get("ammo_current", -1)) == 0, "empty base pistol reload should not make a round fireable immediately")
	var reloading_weapon: Dictionary = controller.get_current_weapon_data()
	_expect(bool(reloading_weapon.get("reloading", false)), "empty base pistol reload should expose reloading state")
	_expect(not bool(reloading_weapon.get("can_fire", true)), "base pistol should be unable to fire during reload")
	_expect(is_equal_approx(float(reload_result.get("special_gauge", -1.0)), 0.0), "empty base pistol reload should spend 150 gauge")
	_expect(audio.pistol_reload_start_calls == 1, "empty base pistol reload should play the reload-start cue once")
	_expect(audio.pistol_reload_round_calls == 0, "empty base pistol reload should wait for progress before playing round cues")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "empty base pistol reload should not spawn a projectile")
	_expect(str(controller.cycle_weapon(1, 1000)) == "pistol", "base pistol reload should block mouse-wheel firearm switching")
	_expect(not controller.set_current_weapon("net_gun"), "base pistol reload should block direct firearm switching")
	var blocked_fire: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		0.0,
		_fire_config(),
		deps
	)
	_expect(str(blocked_fire.get("failure_reason", "")) == "pistol_reloading", "base pistol should not fire while its magazine reload is in progress")
	for _i in range(23):
		runtime.update_input({"action_pressed": false}, 0.0, _fire_config(), deps)
	_expect(int(controller.get_current_weapon_data().get("reload_display_ammo", -1)) == 0, "base pistol reload should not show the first round before the first fifth")
	runtime.update_input({"action_pressed": false}, 0.0, _fire_config(), deps)
	_expect(int(controller.get_current_weapon_data().get("reload_display_ammo", -1)) == 1, "base pistol reload should add bullets one at a time")
	_expect(audio.pistol_reload_round_calls == 1, "base pistol reload should play one cue for the first loaded round")
	for _i in range(95):
		runtime.update_input({"action_pressed": false}, 0.0, _fire_config(), deps)
	var reloaded_weapon: Dictionary = controller.get_current_weapon_data()
	_expect(not bool(reloaded_weapon.get("reloading", true)), "base pistol reload should finish after the original 120-frame reload timer")
	_expect(int(reloaded_weapon.get("ammo_current", -1)) == 5, "base pistol reload should fill the magazine to five rounds after one 150-gauge spend")
	_expect(audio.pistol_reload_round_calls == 5, "base pistol full reload should play one per-round cue for all five bullets")
	_expect(controller.set_current_weapon("net_gun"), "firearm switching should unlock after base pistol reload completes")


func _verify_base_pistol_uses_input_edges_after_switch() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var deps := {
		"commando_weapon_controller": controller,
		"skill_state": state,
		"skill_config": config,
	}
	var fire_config: Dictionary = _fire_config()
	controller.last_switch_msec = Time.get_ticks_msec()
	var suppressed: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		100.0,
		fire_config,
		deps
	)
	_expect(suppressed.is_empty(), "base pistol should suppress the press edge during weapon-switch grace")
	controller.last_switch_msec = -100000
	for _i in range(10):
		var held_result: Dictionary = runtime.update_input(
			{"action_pressed": true, "action_just_pressed": false, "action_just_released": false},
			100.0,
			fire_config,
			deps
		)
		_expect(held_result.is_empty(), "held action without a fresh edge should not fire the base pistol")
	var held_state: Dictionary = _get_dict(runtime.get_actor_draw_context().get("commando_firearm_slingshot_state", {}))
	_expect(not bool(held_state.get("charging", true)), "held action after switch should not revive the removed slingshot charge state")
	var release_result: Dictionary = runtime.update_input(
		{"action_pressed": false, "action_just_pressed": false, "action_just_released": true},
		100.0,
		fire_config,
		deps
	)
	_expect(release_result.is_empty(), "releasing an unstarted held base-pistol input should not fire")
	var fresh_press: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true, "action_just_released": false},
		100.0,
		fire_config,
		deps
	)
	_expect(bool(fresh_press.get("shot_queued", false)), "fresh press edge should queue the base pistol draw/ready animation")


func _verify_pistol_side_wall_bounce() -> void:
	var config: Dictionary = _fire_config()
	var left_runtime := CommandoFirearmRuntime.new()
	left_runtime.projectiles.append({
		"id": 101,
		"weapon_id": "pistol",
		"kind": "bullet",
		"pos": Vector2(4.0, 320.0),
		"prev_pos": Vector2(4.0, 320.0),
		"target": Vector2(380.0, 20.0),
		"velocity": Vector2(-12.0, -4.0),
		"radius": 4.4,
		"hitbox_size": Vector2(9.0, 9.0),
		"life_frames": 44.0,
		"color": Color.WHITE,
	})
	left_runtime.update_effects(1.0, Time.get_ticks_msec(), config, {})
	var left_projectiles: Array = _get_array(left_runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(left_projectiles.size() == 1, "pistol bullet should survive a side-wall bounce")
	var left_bullet: Dictionary = _get_dict(left_projectiles[0])
	_expect(is_equal_approx(_get_vector2(left_bullet.get("pos", Vector2.ZERO), Vector2.ZERO).x, 10.0), "left wall bounce should clamp to the original 10px margin")
	_expect(is_equal_approx(_get_vector2(left_bullet.get("velocity", Vector2.ZERO), Vector2.ZERO).x, 10.2), "left wall bounce should reverse and damp x velocity by 0.85")
	_expect(int(left_bullet.get("wall_bounces", 0)) == 1, "pistol side-wall bounce should be counted once")

	var right_runtime := CommandoFirearmRuntime.new()
	right_runtime.projectiles.append({
		"id": 102,
		"weapon_id": "commando_pistol",
		"kind": "bullet",
		"pos": Vector2(756.0, 320.0),
		"prev_pos": Vector2(756.0, 320.0),
		"target": Vector2(380.0, 20.0),
		"velocity": Vector2(12.0, -4.0),
		"radius": 5.0,
		"hitbox_size": Vector2(10.0, 10.0),
		"life_frames": 44.0,
		"color": Color.WHITE,
	})
	right_runtime.update_effects(1.0, Time.get_ticks_msec(), config, {})
	var right_projectiles: Array = _get_array(right_runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(right_projectiles.size() == 1, "Commando pistol bullet should also survive a side-wall bounce")
	var right_bullet: Dictionary = _get_dict(right_projectiles[0])
	_expect(is_equal_approx(_get_vector2(right_bullet.get("pos", Vector2.ZERO), Vector2.ZERO).x, 750.0), "right wall bounce should clamp to the original 10px margin")
	_expect(is_equal_approx(_get_vector2(right_bullet.get("velocity", Vector2.ZERO), Vector2.ZERO).x, -10.2), "right wall bounce should reverse and damp x velocity by 0.85")
	_expect(int(right_bullet.get("wall_bounces", 0)) == 1, "Commando pistol side-wall bounce should be counted once")


func _verify_commando_pistol_ammo_empty_and_instant_fire() -> void:
	var setup: Dictionary = _build_setup("commando_pistol")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var audio: Object = setup.get("audio", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()

	var first_queue: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(first_queue.get("fired", false)), "Commando pistol should fire on the input frame without a ready motion")
	_expect(not bool(first_queue.get("shot_queued", false)), "Commando pistol input should not queue an aimed shot")
	_expect(int(first_queue.get("ammo_current", -1)) == 11, "Beretta should spend one bullet from the 12-round loaded magazine on input")
	_expect(int(first_queue.get("magazines_current", -1)) == 0, "Beretta should not expose spare magazines")
	_expect(is_equal_approx(float(first_queue.get("cooldown_frames", 0.0)), 30.0), "Beretta should fire twice as fast as the base pistol")
	_expect(is_equal_approx(float(first_queue.get("control_lock_frames", -1.0)), 0.0), "Beretta should not lock movement for a ready motion")
	_expect(is_equal_approx(float(first_queue.get("fire_delay_frames", -1.0)), 0.0), "Beretta should have no draw/aim delay")
	_expect(audio.pistol_ready_calls == 0, "Commando pistol instant fire should skip the ready/draw cue")
	var projectiles: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(projectiles.size() == 1 and str(_get_dict(projectiles[0]).get("weapon_id", "")) == "commando_pistol", "instant Commando pistol fire should create the real pistol projectile")
	var pistol_projectile: Dictionary = _get_dict(projectiles[0])
	_expect(is_equal_approx(_get_vector2(pistol_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO).length(), 30.0), "Beretta bullet should fly 20% faster than the base pistol")
	_expect(
		abs(float(pistol_projectile.get("angle_offset", 999.0))) <= CommandoFirearmRuntime.BERETTA_SPREAD_RADIANS,
		"Commando pistol bullet should use the 30% tighter Beretta spread"
	)
	var shells: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_shell_casings", []))
	_expect(shells.size() == 1 and str(_get_dict(shells[0]).get("weapon_id", "")) == "commando_pistol", "Commando pistol fire should eject a pistol shell casing")
	_expect(_get_array(audio.fire_calls) == ["commando_pistol"], "Commando pistol gunshot should play immediately on input")

	var blocked: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(blocked.get("fire_failed", false)) and str(blocked.get("failure_reason", "")) == "pistol_cooldown", "Beretta should block repeat input during its faster internal cooldown")

	_wait_pistol_ready(runtime, deps, config)
	for _shot_index in range(11):
		_queue_and_resolve_pistol_shot(runtime, deps, config)
		_wait_pistol_ready(runtime, deps, config)
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 0, "twelve Beretta shots should empty the 12-round loaded magazine")
	_expect(int(controller.get_current_weapon_data().get("magazines_current", -1)) == 0, "Beretta should stay without spare magazines after spending bullets")

	var empty_fire: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(empty_fire.get("fire_failed", false)), "empty Beretta fire input should fail instead of reloading")
	_expect(str(empty_fire.get("failure_reason", "")) == "pistol_empty", "empty Beretta should require the reload skill path")
	var empty_weapon: Dictionary = controller.get_current_weapon_data()
	_expect(not bool(empty_weapon.get("reloading", false)), "empty Beretta should not enter a reload timer")
	_expect(int(empty_weapon.get("ammo_current", -1)) == 0, "empty Beretta fire input should not refill ammo")
	_expect(str(empty_weapon.get("ammo_text", "")) == "탄약 0/12", "empty Beretta ammo text should stay ammo-only")
	_expect(audio.pistol_reload_start_calls == 0, "empty Beretta fire input should not play a reload-start cue")
	_expect(audio.pistol_reload_round_calls == 0, "empty Beretta fire input should not play reload-round cues")


func _verify_pistol_headshot_legshot_status_and_gauge() -> void:
	var fallback_roll: float = float(CommandoFirearmValueUtils.get_pistol_shot_roll({}, {}))
	_expect(fallback_roll > 0.0 and fallback_roll <= 1.0, "missing pistol shot roll should use a fresh random roll instead of clamping the sentinel into a guaranteed headshot")
	var sentinel_roll: float = float(CommandoFirearmValueUtils.get_pistol_shot_roll({}, {"commando_pistol_shot_roll": -1.0}))
	_expect(sentinel_roll > 0.0 and sentinel_roll <= 1.0, "negative pistol shot roll sentinel should fall back to random like the Python random.random path")

	var normal_runtime := CommandoFirearmRuntime.new()
	var normal_status := FakeStatusEffectState.new()
	var normal_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	normal_projectile["shot_roll"] = 0.99
	normal_runtime._register_projectile_hit(normal_projectile, _fire_config(), {"status_effect_state": normal_status})
	var normal_calls: Array = _get_array(normal_status.get_calls_for_source("commando_firearm_commando_pistol"))
	_expect(normal_calls.size() == 1, "normal pistol hit should apply the shared bullet stun source")
	_expect(str(_get_dict(normal_calls[0]).get("status_id", "")) == "stun", "normal pistol hit should still stun the boss")
	_expect(is_equal_approx(float(_get_dict(normal_calls[0]).get("duration_frames", 0.0)), 42.0), "normal Commando pistol stun should match the requested 0.7-second tuning")
	var normal_status_data: Dictionary = _get_dict(_get_dict(normal_calls[0]).get("data", {}))
	_expect(is_equal_approx(abs(float(normal_status_data.get("knockback_vel", 0.0))), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER), "normal Commando pistol stun should restore the original light knockback")
	_expect(bool(normal_status_data.get("knockback_active", false)), "normal Commando pistol stun should expose a short knockback motion")
	_expect(is_equal_approx(float(normal_status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_FRAMES), "normal Commando pistol knockback should use the original short motion window")
	_expect(is_equal_approx(float(normal_status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_DECAY_PER_FRAME), "normal Commando pistol knockback should decay like the original boss stun drift")
	var normal_result: Dictionary = _get_dict(_get_dict(_get_array(normal_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(str(normal_result.get("pistol_hit_kind", "")) == "normal", "pistol roll outside head/leg ranges should remain a normal hit")
	_expect(is_equal_approx(float(normal_result.get("commando_firearm_special_gauge_gain", 0.0)), 30.0), "normal pistol hit should expose Python 30 gauge gain")
	_expect(is_equal_approx(float(normal_result.get("pistol_head_chance", 0.0)), 0.10), "pistol headshot chance should match the Python 10% base chance")
	_expect(is_equal_approx(float(normal_result.get("pistol_leg_chance", 0.0)), 0.12), "pistol legshot chance should match the Python 12% base chance")
	_expect(_get_array(normal_runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", [])).is_empty(), "normal pistol hit should not spawn headshot/legshot text")

	var real_normal_runtime := CommandoFirearmRuntime.new()
	var real_normal_status := StatusEffectState.new()
	var real_normal_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	real_normal_projectile["shot_roll"] = 0.99
	real_normal_runtime._register_projectile_hit(real_normal_projectile, _fire_config(), {"status_effect_state": real_normal_status})
	var normal_ai_context: Dictionary = _fire_config()
	var normal_status_context: Dictionary = real_normal_status.get_boss_ai_context()
	for key in normal_status_context.keys():
		normal_ai_context[key] = normal_status_context[key]
	var normal_stunned_motion: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(328.0, 62.0), -2.5, normal_ai_context)
	_expect(is_equal_approx(float(normal_stunned_motion.get("boss_vel", 999.0)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER), "normal Commando pistol stun should replace previous boss movement with pistol knockback")
	_expect(is_equal_approx(_get_vector2(normal_stunned_motion.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x, 328.0 + CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER), "normal Commando pistol stun should nudge the boss on the first stun frame")
	for _i in range(int(CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_FRAMES)):
		real_normal_status.update(1.0)
	var settled_ai_context: Dictionary = _fire_config()
	var settled_status_context: Dictionary = real_normal_status.get_boss_ai_context()
	for key in settled_status_context.keys():
		settled_ai_context[key] = settled_status_context[key]
	var settled_motion: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(328.0, 62.0), -2.5, settled_ai_context)
	_expect(is_equal_approx(float(settled_motion.get("boss_vel", 999.0)), 0.0), "normal Commando pistol stun should stop knockback before the full 0.7-second stun ends")
	_expect(is_equal_approx(_get_vector2(settled_motion.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x, 328.0), "normal Commando pistol stun should hold position after the short knockback window")

	var head_runtime := CommandoFirearmRuntime.new()
	var head_status := FakeStatusEffectState.new()
	var head_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	head_projectile["shot_roll"] = 0.0
	head_runtime._register_projectile_hit(head_projectile, _fire_config(), {"status_effect_state": head_status})
	var head_calls: Array = _get_array(head_status.get_calls_for_source("commando_firearm_pistol_headshot"))
	_expect(head_calls.size() == 1, "pistol headshot should apply a dedicated boss stun status")
	_expect(str(_get_dict(head_calls[0]).get("status_id", "")) == "stun", "pistol headshot should be a stun status")
	_expect(is_equal_approx(float(_get_dict(head_calls[0]).get("duration_frames", 0.0)), 108.0), "pistol headshot stun should match the 1.8s tuning")
	var head_result: Dictionary = _get_dict(_get_dict(_get_array(head_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(str(head_result.get("pistol_hit_kind", "")) == "headshot", "pistol headshot metadata should preserve hit kind")
	_expect(is_equal_approx(float(head_result.get("commando_firearm_special_gauge_gain", 0.0)), 50.0), "pistol headshot should expose Python 50 gauge gain")
	_expect(is_equal_approx(float(head_result.get("pistol_head_chance", 0.0)), 0.10), "headshot result should expose the Python 10% base chance")
	_expect(is_equal_approx(float(head_result.get("pistol_leg_chance", 0.0)), 0.12), "headshot result should expose the Python 12% legshot base chance")
	var head_status_data: Dictionary = _get_dict(_get_dict(head_calls[0]).get("data", {}))
	_expect(is_equal_approx(float(head_status_data.get("knockback_vel", 999.0)), 0.0), "pistol headshot stun should not inherit bullet knockback velocity")
	_expect(not bool(head_status_data.get("knockback_active", true)), "pistol headshot stun should freeze the boss in place")
	var head_feedbacks: Array = _get_array(head_runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", []))
	_expect(head_feedbacks.size() == 1, "pistol headshot should expose one text feedback draw context")
	_expect(str(_get_dict(head_feedbacks[0]).get("text", "")) == "헤드샷!", "pistol headshot feedback should use Korean text")

	var real_head_runtime := CommandoFirearmRuntime.new()
	var real_head_status := StatusEffectState.new()
	var real_head_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	real_head_projectile["shot_roll"] = 0.0
	real_head_runtime._register_projectile_hit(real_head_projectile, _fire_config(), {"status_effect_state": real_head_status})
	var ai_context: Dictionary = _fire_config()
	var status_context: Dictionary = real_head_status.get_boss_ai_context()
	for key in status_context.keys():
		ai_context[key] = status_context[key]
	var stunned_motion: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(328.0, 62.0), -2.5, ai_context)
	_expect(is_equal_approx(float(stunned_motion.get("boss_vel", 999.0)), 0.0), "pistol headshot stun should cancel the boss previous movement direction")
	_expect(is_equal_approx(_get_vector2(stunned_motion.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x, 328.0), "pistol headshot stun should keep boss x position fixed on the first stun frame")

	var leg_runtime := CommandoFirearmRuntime.new()
	var leg_status := FakeStatusEffectState.new()
	var leg_ai := FakeAiState.new()
	var leg_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	leg_projectile["shot_roll"] = 0.15
	leg_runtime._register_projectile_hit(leg_projectile, _fire_config(), {"status_effect_state": leg_status, "ai_state": leg_ai})
	var leg_calls: Array = _get_array(leg_status.get_calls_for_source("commando_firearm_pistol_legshot"))
	_expect(leg_calls.size() == 1, "pistol legshot should apply a dedicated boss slow status")
	_expect(str(_get_dict(leg_calls[0]).get("status_id", "")) == "slow", "pistol legshot should be a slow status")
	_expect(is_equal_approx(float(_get_dict(leg_calls[0]).get("duration_frames", 0.0)), 132.0), "pistol legshot slow should match Python 2.2s duration")
	_expect(is_equal_approx(float(_get_dict(_get_dict(leg_calls[0]).get("data", {})).get("multiplier", 0.0)), 0.70), "pistol legshot slow should keep the Python 70% speed multiplier")
	var leg_result: Dictionary = _get_dict(_get_dict(_get_array(leg_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(str(leg_result.get("pistol_hit_kind", "")) == "legshot", "pistol legshot metadata should preserve hit kind")
	_expect(is_equal_approx(float(leg_result.get("commando_firearm_special_gauge_gain", 0.0)), 40.0), "pistol legshot should expose Python 40 gauge gain")
	_expect(is_equal_approx(float(leg_result.get("pistol_head_chance", 0.0)), 0.10), "legshot result should expose the Python 10% headshot base chance")
	_expect(is_equal_approx(float(leg_result.get("pistol_leg_chance", 0.0)), 0.12), "legshot result should expose the Python 12% base chance")
	_expect(leg_ai.knockback_calls == 1, "pistol legshot should still apply the Python bullet knockback without adding stun")
	_expect(is_equal_approx(abs(float(leg_ai.last_velocity)), CommandoFirearmRuntime.PISTOL_BOSS_KNOCKBACK_POWER), "pistol legshot knockback should use the doubled pistol knockback power")
	var leg_feedbacks: Array = _get_array(leg_runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", []))
	_expect(leg_feedbacks.size() == 1, "pistol legshot should expose one text feedback draw context")
	_expect(str(_get_dict(leg_feedbacks[0]).get("text", "")) == "레그샷!", "pistol legshot feedback should use Korean text")
	for i in range(61):
		leg_runtime.update_effects(1.0, Time.get_ticks_msec(), _fire_config(), {"status_effect_state": leg_status})
	_expect(_get_array(leg_runtime.get_actor_draw_context().get("commando_firearm_pistol_feedbacks", [])).is_empty(), "pistol feedback text should expire after the Python 60-frame timer")

	var head_boundary_runtime := CommandoFirearmRuntime.new()
	var head_boundary_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	head_boundary_projectile["shot_roll"] = 0.10
	head_boundary_runtime._register_projectile_hit(head_boundary_projectile, _fire_config(), {})
	var head_boundary_result: Dictionary = _get_dict(_get_dict(_get_array(head_boundary_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(str(head_boundary_result.get("pistol_hit_kind", "")) == "legshot", "pistol roll equal to the 10% headshot boundary should fall through to legshot like Python")

	var leg_boundary_runtime := CommandoFirearmRuntime.new()
	var leg_boundary_projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	leg_boundary_projectile["shot_roll"] = 0.22
	leg_boundary_runtime._register_projectile_hit(leg_boundary_projectile, _fire_config(), {})
	var leg_boundary_result: Dictionary = _get_dict(_get_dict(_get_array(leg_boundary_runtime.get_recent_hit_events())[0]).get("result", {}))
	_expect(str(leg_boundary_result.get("pistol_hit_kind", "")) == "normal", "pistol roll equal to head+leg chance should fall through to a normal hit like Python")


func _verify_pistol_hit_gauge_result_handoff() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var feedback := FakeFeedback.new()
	var status := FakeStatusEffectState.new()
	var projectile: Dictionary = _direct_projectile("commando_pistol", Vector2(330.0, 82.0), Vector2(0.0, -18.0))
	projectile["shot_roll"] = 0.0
	var context: Dictionary = _fire_config()
	context["special_gauge"] = 470.0
	context["gauge_max"] = 500.0
	context["dash_snapshot"] = {"max_tokens": 1, "tokens": 1}
	runtime._register_projectile_hit(projectile, context, {"status_effect_state": status})

	var result: Dictionary = BattleEffectsUpdateController.new().update(1.0 / 60.0, context, {
		"commando_firearm_runtime": runtime,
		"feedback": feedback,
		"status_effect_state": status,
	})
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 500.0), "pistol headshot gauge gain should be applied through the effects controller and clamp to max")
	_expect(is_equal_approx(float(result.get("commando_firearm_special_gauge_gain", 0.0)), 50.0), "effects result should preserve the raw pistol gauge gain")
	_expect(is_equal_approx(float(result.get("commando_firearm_special_gauge_gain_applied", 0.0)), 30.0), "effects result should expose the clamped applied pistol gauge gain")
	_expect(str(result.get("commando_firearm_last_pistol_hit_kind", "")) == "headshot", "effects result should preserve the last pistol hit kind for feedback")
	_expect(is_equal_approx(float(result.get("commando_firearm_pistol_feedback_timer_frames", 0.0)), 60.0), "effects result should preserve pistol hit feedback text timer")
	_expect(feedback.gauge_flash_calls == 1, "pistol gauge gain handoff should trigger gauge flash feedback")


func _verify_projectile_hitbox_profiles() -> void:
	var config: Dictionary = _fire_config()

	var ak_near_center_miss := {
		"weapon_id": "ak47",
		"kind": "bullet",
		"pos": Vector2(378.0, 107.0),
		"prev_pos": Vector2(378.0, 131.0),
		"velocity": Vector2(0.0, -24.0),
		"radius": 3.6,
		"life_frames": 20.0,
		"target": _boss_center(config),
	}
	_expect(_get_runtime_projectile_impact_reason(ak_near_center_miss, config) == "", "AK-47 should use the Python 6x6 bullet rect instead of target-center proximity")

	var ak_edge_hit := ak_near_center_miss.duplicate(true)
	ak_edge_hit["pos"] = Vector2(378.0, 100.0)
	ak_edge_hit["prev_pos"] = Vector2(378.0, 124.0)
	_expect(_get_runtime_projectile_impact_reason(ak_edge_hit, config) == "target", "AK-47 bullet rect should hit when the 6x6 box overlaps the boss")

	var net_expanded_hit := {
		"weapon_id": "net_gun",
		"kind": "net",
		"pos": Vector2(266.0, 82.0),
		"prev_pos": Vector2(246.0, 82.0),
		"velocity": Vector2(10.0, 0.0),
		"radius": 13.0,
		"life_frames": 30.0,
		"target": _boss_center(config),
	}
	_expect(_get_runtime_projectile_impact_reason(net_expanded_hit, config) == "target", "net gun should use the Python expanded boss capture hitbox")

	var bazooka_wall_hit := {
		"weapon_id": "bazooka",
		"kind": "rocket",
		"pos": Vector2(300.0, 18.0),
		"prev_pos": Vector2(300.0, 35.0),
		"velocity": Vector2(0.0, -11.0),
		"radius": 9.5,
		"life_frames": 30.0,
		"target": Vector2(300.0, 20.0),
	}
	_expect(_get_runtime_projectile_impact_reason(bazooka_wall_hit, config) == "target", "bazooka wall burst should use the configured explosion radius")
	_expect(is_equal_approx(_get_vector2(bazooka_wall_hit.get("pos", Vector2.ZERO), Vector2.ZERO).y, 20.0), "bazooka wall impact should clamp the visual burst to the back wall")

	var bazooka_wall_miss := bazooka_wall_hit.duplicate(true)
	bazooka_wall_miss["pos"] = Vector2(40.0, 18.0)
	bazooka_wall_miss["prev_pos"] = Vector2(40.0, 35.0)
	bazooka_wall_miss["target"] = Vector2(40.0, 20.0)
	_expect(_get_runtime_projectile_impact_reason(bazooka_wall_miss, config) == "wall", "bazooka wall burst outside explosion radius should still detonate as an environment impact")

	var bazooka_target_miss := bazooka_wall_hit.duplicate(true)
	bazooka_target_miss["pos"] = Vector2(40.0, 82.0)
	bazooka_target_miss["prev_pos"] = Vector2(40.0, 98.0)
	bazooka_target_miss["velocity"] = Vector2(0.0, -16.0)
	bazooka_target_miss["target"] = Vector2(40.0, 82.0)
	_expect(_get_runtime_projectile_impact_reason(bazooka_target_miss, config) == "", "bazooka should not disappear at the aim point before reaching the wall")


func _verify_lingering_field_runtime() -> void:
	var net_setup: Dictionary = _build_setup("net_gun")
	var net_runtime: Object = net_setup.get("runtime", null)
	var net_deps: Dictionary = net_setup.get("deps", {})
	var net_status: Object = net_setup.get("status_effect_state", null)
	var config: Dictionary = _fire_config()
	net_runtime._register_projectile_hit(_direct_projectile("net_gun", Vector2(350.0, 82.0), Vector2(0.0, -10.0)), config, net_deps)
	var net_context: Dictionary = net_runtime.get_actor_draw_context()
	var net_fields: Array = _get_array(net_context.get("commando_firearm_lingering_effects", []))
	_expect(net_fields.size() == 1, "net gun impact should leave one lingering net field")
	_expect(str(_get_dict(net_fields[0]).get("kind", "")) == "net_field", "net lingering effect should expose net_field kind")
	_expect(is_equal_approx(float(_get_dict(net_fields[0]).get("timer_frames", 0.0)), 240.0), "net lingering effect should start at the Python 4s duration")
	_expect(_get_array(net_status.get_calls_for_source("commando_firearm_net_gun")).is_empty(), "net direct hit should not apply an immediate slow status")
	net_runtime.update_effects(1.0, Time.get_ticks_msec(), config, net_deps)
	var net_calls_after_tick: Array = _get_array(net_status.get_calls_for_source("commando_firearm_net_gun"))
	_expect(net_calls_after_tick.is_empty(), "active net field should not refresh boss slow while the boss remains inside")

	var drone_setup: Dictionary = _build_setup("suicide_drone")
	var drone_runtime: Object = drone_setup.get("runtime", null)
	var drone_deps: Dictionary = drone_setup.get("deps", {})
	var drone_status: Object = drone_setup.get("status_effect_state", null)
	var drone_active_items: Object = drone_setup.get("active_item_runtime", null)
	drone_runtime._register_projectile_hit(_direct_projectile("suicide_drone", Vector2(360.0, 82.0), Vector2(8.0, -8.0)), config, drone_deps)
	var drone_fields: Array = _get_array(drone_runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", []))
	_expect(drone_fields.is_empty(), "suicide drone should not create a separate Commando-only fire zone")
	var fire_zone_calls: Array = _get_array(drone_active_items.molotov_fire_zone_calls)
	_expect(fire_zone_calls.size() == 1, "suicide drone detonation should register one molotov fire zone")
	_expect(_get_vector2(_get_dict(fire_zone_calls[0]).get("center", Vector2.ZERO), Vector2.ZERO) == Vector2(360.0, 82.0), "suicide drone molotov fire zone should spawn at the detonation center")
	_expect(not bool(_get_dict(fire_zone_calls[0]).get("play_feedback_audio", true)), "suicide drone should reuse molotov fire-zone gameplay without double-playing molotov explosion feedback")
	drone_runtime.update_effects(1.0, Time.get_ticks_msec(), config, drone_deps)
	var drone_calls_after_tick: Array = _get_array(drone_status.get_calls_for_source("commando_firearm_suicide_drone"))
	_expect(drone_calls_after_tick.size() == 1, "suicide drone should not add Commando-only lingering slow on top of the molotov fire-zone path")


func _verify_fire_support_call_lifecycle() -> void:
	var setup: Dictionary = _build_setup("fire_support")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var deps: Dictionary = setup.get("deps", {})
	var status_effect_state: Object = setup.get("status_effect_state", null)
	var audio: Object = setup.get("audio", null)
	var config: Dictionary = _fire_config()

	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(result.get("fired", false)), "ready fire support should spend the call ticket")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 1, "fire support should consume one radio per call")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "fire support should keep one remaining call after the first radio use")
	_expect(audio.fire_support_radio_calls == 1, "fire support activation should play its radio cue")
	_expect(audio.fire_support_aircraft_play_calls == 0, "fire support should not start aircraft loop during radio lock")
	_expect(audio.supply_radio_calls == 0, "fire support should prefer its dedicated radio cue over the supply fallback")
	_expect(bool(runtime.is_player_control_locked()), "fire support radio lock should hold player control for the Python 42-frame call")
	var initial_context: Dictionary = runtime.get_actor_draw_context()
	var initial_calls: Array = _get_array(initial_context.get("commando_firearm_support_calls", []))
	_expect(initial_calls.size() == 1, "fire support should create one active support-call lifecycle")
	var initial_call: Dictionary = _get_dict(initial_calls[0])
	_expect(str(initial_call.get("state", "")) == "calling", "fire support should begin in the radio-call state")
	_expect(bool(initial_call.get("radio_active", false)), "fire support should expose active radio motion during call lock")
	_expect(float(initial_call.get("delay_frames", 0.0)) >= 120.0 and float(initial_call.get("delay_frames", 0.0)) <= 180.0, "fire support delay should stay in the Python 120-180 frame range")
	var expected_bomb_total: int = int(initial_call.get("bombs_total", 0))
	_expect(expected_bomb_total == 2, "fire support should prepare the tuned 2-bomb strike")
	_expect(not bool(runtime.is_fire_support_aircraft_audio_active()), "fire support aircraft audio should stay inactive before aircraft entry")
	_expect(_get_array(initial_context.get("commando_firearm_projectiles", [])).is_empty(), "fire support should not drop a bomb on the call frame")

	for i in range(44):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var inbound_calls: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_support_calls", []))
	_expect(inbound_calls.size() == 1, "fire support should stay active after the radio-call lock")
	_expect(str(_get_dict(inbound_calls[0]).get("state", "")) == "inbound", "fire support should enter inbound delay before bombing")
	_expect(not bool(_get_dict(inbound_calls[0]).get("radio_active", true)), "fire support radio motion should end after the Python 42-frame lock")
	_expect(not bool(runtime.is_player_control_locked()), "fire support should release player control after the radio lock")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "fire support inbound delay should not spawn bombs early")

	for i in range(240):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		var active_calls: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_support_calls", []))
		if active_calls.size() == 1 and bool(_get_dict(active_calls[0]).get("aircraft_active", false)):
			break
	var strike_context: Dictionary = runtime.get_actor_draw_context()
	var strike_calls: Array = _get_array(strike_context.get("commando_firearm_support_calls", []))
	_expect(strike_calls.size() == 1 and bool(_get_dict(strike_calls[0]).get("aircraft_active", false)), "fire support should expose the aircraft once the strike starts")
	var strike_call: Dictionary = _get_dict(strike_calls[0])
	var aircraft_velocity: Vector2 = _get_vector2(strike_call.get("aircraft_velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(aircraft_velocity.x, 10.8), "fire support aircraft should fly at the doubled strike speed")
	_expect(float(strike_call.get("aircraft_curve_amplitude", 0.0)) > 0.0, "fire support aircraft should expose curved flight metadata")
	var strike_aircraft_pos: Vector2 = _get_vector2(strike_call.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO)
	_expect(strike_aircraft_pos.x < -300.0, "fire support aircraft should enter from the pillar-edge flight band")
	_expect(strike_aircraft_pos.y > 240.0 and strike_aircraft_pos.y < 420.0, "fire support aircraft should fly through the screen-center lane")
	_expect(audio.fire_support_aircraft_play_calls == 1, "fire support aircraft entry should start the dedicated aircraft loop")
	_expect(audio.supply_aircraft_play_calls == 0, "fire support aircraft loop should not use the supply fallback when the dedicated method exists")
	_expect(bool(runtime.is_fire_support_aircraft_audio_active()), "fire support should expose active aircraft loop state during strike")
	var aircraft_rect: Rect2 = runtime.get_fire_support_aircraft_collision_rect(int(strike_call.get("id", 0)))
	_expect(aircraft_rect.size.x > 0.0 and aircraft_rect.size.y > 0.0, "fire support aircraft should expose its Python-sized collision rect")
	var collision_scene: Dictionary = config.duplicate(true)
	collision_scene["previous_ball_pos"] = aircraft_rect.get_center() + Vector2(0.0, -90.0)
	collision_scene["ball_pos"] = aircraft_rect.get_center()
	collision_scene["ball_vel"] = Vector2(0.0, 12.0)
	collision_scene["ball_size"] = 28.6
	_expect(not bool(runtime.resolve_ball_collision(collision_scene, config, deps)), "fire support aircraft should keep Python no-crash pass-through on ball contact")
	var post_collision_calls: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_support_calls", []))
	_expect(post_collision_calls.size() == 1 and bool(_get_dict(post_collision_calls[0]).get("aircraft_active", false)), "fire support ball contact should not cancel the bomber")
	_expect(audio.fire_support_aircraft_stop_calls == 0, "fire support ball contact should not stop the aircraft loop")
	_expect(_get_array(strike_context.get("commando_firearm_projectiles", [])).is_empty(), "fire support aircraft should wait for the tuned drop-arm window before the first missile")

	for i in range(90):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if not _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty():
			break
	var first_bombs: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))
	_expect(not first_bombs.is_empty() or not _get_array(runtime.get_recent_hit_events()).is_empty(), "fire support should spawn or resolve the first wall-flight missile after the drop-arm window")
	if not first_bombs.is_empty():
		var first_bomb: Dictionary = _get_dict(first_bombs[0])
		_expect(str(first_bomb.get("kind", "")) == "support", "fire support wall-flight ordnance should expose support projectile kind")
		_expect(str(first_bomb.get("support_impact_mode", "")) == "opponent_wall", "fire support missile should use opponent-wall impact mode")
		_expect(is_equal_approx(float(first_bomb.get("gravity", 0.0)), 0.0), "fire support missile should fly without gravity drift")
		_expect(is_equal_approx(float(first_bomb.get("support_flight_frames", 0.0)), 90.0), "fire support missile should take about 1.5 seconds to reach the wall")
		var first_bomb_target: Vector2 = _get_vector2(first_bomb.get("target", Vector2.ZERO), Vector2.ZERO)
		var marked_target: Vector2 = _get_vector2(strike_call.get("target", Vector2.ZERO), Vector2.ZERO)
		_expect(is_equal_approx(first_bomb_target.y, 22.0), "fire support missile should target the opponent-side wall")
		_expect(abs(first_bomb_target.x - marked_target.x) <= 300.0, "fire support missile target x should scatter within 300px of the marked point")
		_expect(float(_get_vector2(first_bomb.get("velocity", Vector2.ZERO), Vector2.ZERO).y) < 0.0, "fire support missile should travel toward the boss-side wall")

	for i in range(620):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if _get_array(audio.impact_calls).count("fire_support") >= expected_bomb_total:
			break
	var hit_events: Array = _get_array(runtime.get_recent_hit_events())
	if not hit_events.is_empty():
		_expect(str(_get_dict(hit_events[0]).get("weapon_id", "")) == "fire_support", "fire support missile hit should preserve weapon id")
		_expect(int(_get_dict(_get_dict(hit_events[0]).get("result", {})).get("damage_units", 0)) == 1, "fire support missile hit should preserve damage metadata")
	var status_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_firearm_fire_support"))
	_expect(status_calls.size() <= expected_bomb_total, "scattered fire support missiles should not apply more boss stuns than spawned bombs")
	_expect(_get_array(audio.impact_calls).count("fire_support") >= expected_bomb_total, "each scattered fire support missile should resolve with impact audio")
	for i in range(760):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if _get_array(runtime.get_actor_draw_context().get("commando_firearm_support_calls", [])).is_empty():
			break
	_expect(audio.fire_support_aircraft_stop_calls == 1, "fire support strike completion should stop the aircraft loop")
	_expect(not bool(runtime.is_fire_support_aircraft_audio_active()), "fire support should clear aircraft loop state after strike completion")

	var cleanup_setup: Dictionary = _build_setup("fire_support")
	var cleanup_runtime: Object = cleanup_setup.get("runtime", null)
	var cleanup_deps: Dictionary = cleanup_setup.get("deps", {})
	var cleanup_audio: Object = cleanup_setup.get("audio", null)
	cleanup_runtime.update_input({"action_pressed": true}, 500.0, _fire_config(), cleanup_deps)
	for i in range(260):
		cleanup_runtime.update_effects(1.0, Time.get_ticks_msec(), _fire_config(), cleanup_deps)
		if bool(cleanup_runtime.is_fire_support_aircraft_audio_active()):
			break
	_expect(bool(cleanup_runtime.is_fire_support_aircraft_audio_active()), "round-cleanup setup should have an active fire-support aircraft loop")
	cleanup_runtime.reset_round(cleanup_deps)
	_expect(cleanup_audio.fire_support_aircraft_stop_calls == 1, "fire support reset_round should stop the aircraft loop")
	_expect(not bool(cleanup_runtime.has_visible_effects()), "fire support reset_round should clear visible support effects")


func _verify_bowling_trap_capture_launch_lifecycle() -> void:
	var setup: Dictionary = _build_setup("bowling_trap")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var deps: Dictionary = setup.get("deps", {})
	var audio: Object = setup.get("audio", null)
	var ball_effects: Object = setup.get("ball_effects", null)
	var config: Dictionary = _fire_config()

	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(result.get("fired", false)), "ready bowling trap should spend one trap")
	_expect(int(result.get("ammo_current", -1)) == 2, "bowling trap should spend one round from the Python 3-trap ammo pool")
	_expect(int(result.get("ammo_max", -1)) == 3, "bowling trap should expose the Python 3-trap ammo max")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 2, "bowling trap controller ammo should stay in sync after the runtime spend")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "bowling trap should remain fire-capable while traps remain")
	_expect(is_equal_approx(float(result.get("cooldown_frames", 0.0)), 120.0), "bowling trap should start the Python 120-frame cooldown")
	_expect(is_equal_approx(float(result.get("control_lock_frames", 0.0)), 30.0), "bowling trap should expose the Python 30-frame control lock")
	_expect(is_equal_approx(float(result.get("install_pose_frames", 0.0)), 48.0), "bowling trap should expose the Python 48-frame install pose")
	_expect(bool(runtime.is_player_control_locked()), "bowling trap install should lock player control immediately after activation")
	var initial_context: Dictionary = runtime.get_actor_draw_context()
	var initial_state: Dictionary = _get_dict(initial_context.get("commando_firearm_bowling_trap_state", {}))
	_expect(bool(initial_state.get("installing", false)), "bowling trap should expose a renderer install state while arming")
	_expect(is_equal_approx(float(initial_state.get("cooldown_frames", 0.0)), 120.0), "bowling trap renderer state should mirror the runtime cooldown")
	_expect(is_equal_approx(float(initial_state.get("control_lock_frames", 0.0)), 30.0), "bowling trap renderer state should mirror the runtime control lock")
	_expect(is_equal_approx(float(initial_state.get("install_progress", -1.0)), 0.0), "bowling trap renderer state should begin with an empty install gauge")
	var initial_traps: Array = _get_array(initial_context.get("commando_firearm_bowling_traps", []))
	_expect(initial_traps.size() == 1, "bowling trap fire should create one installed trap lifecycle")
	_expect(str(_get_dict(initial_traps[0]).get("state", "")) == "installing", "bowling trap should begin with the install timer")
	_expect(_get_array(initial_context.get("commando_firearm_projectiles", [])).is_empty(), "bowling trap should not fire a boss projectile")

	var held_repeat: Dictionary = runtime.update_input({"action_pressed": true, "action_just_pressed": false}, 500.0, config, deps)
	_expect(held_repeat.is_empty(), "held bowling-trap action without a fresh edge should not install another trap")
	runtime.update_input({"action_pressed": false}, 500.0, config, deps)
	var blocked_repeat: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(blocked_repeat.get("fire_failed", false)) and str(blocked_repeat.get("failure_reason", "")) == "bowling_trap_control_lock", "bowling trap should block repeat input during the 30-frame install lock")

	var field_setup: Dictionary = _build_setup("bowling_trap")
	var field_runtime: Object = field_setup.get("runtime", null)
	var field_controller: Object = field_setup.get("controller", null)
	var upper_field_config: Dictionary = _fire_config()
	upper_field_config["player_pos"] = Vector2(302.0, 250.0)
	var upper_field_result: Dictionary = field_runtime.update_input({"action_pressed": true}, 500.0, upper_field_config, field_setup.get("deps", {}))
	_expect(bool(upper_field_result.get("fire_failed", false)) and str(upper_field_result.get("failure_reason", "")) == "bowling_trap_install_field", "bowling trap should only install in the lower 60% player field")
	_expect(int(field_controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "failed upper-field bowling trap install should not spend ammo")
	_expect(_get_array(field_runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", [])).is_empty(), "failed upper-field bowling trap install should not leave a trap body")

	for i in range(49):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var waiting_context: Dictionary = runtime.get_actor_draw_context()
	var waiting_traps: Array = _get_array(waiting_context.get("commando_firearm_bowling_traps", []))
	_expect(waiting_traps.size() == 1, "installed bowling trap should remain on the player side")
	var trap: Dictionary = _get_dict(waiting_traps[0])
	_expect(str(trap.get("state", "")) == "waiting", "bowling trap should finish installing into the waiting state")
	var trap_pos: Vector2 = _get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)

	var scene: Dictionary = config.duplicate(true)
	scene["ball_active"] = true
	scene["ball_size"] = 28.6
	scene["ball_pos"] = trap_pos + Vector2(0.0, -2.0)
	scene["ball_vel"] = Vector2(0.0, 7.0)
	var capture_result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), scene, deps)
	_expect(bool(capture_result.get("commando_bowling_trap_captured", false)), "downward ball should be captured by the waiting bowling trap")
	_expect(bool(capture_result.get("skip_ball_motion_step", false)), "captured bowling trap ball should skip normal motion")
	_expect(_get_vector2(capture_result.get("ball_vel", Vector2.ONE), Vector2.ONE) == Vector2.ZERO, "captured bowling trap ball should be held still")
	_expect(_get_array(audio.impact_calls).count("bowling_trap") == 1, "bowling trap capture should trigger exactly one snap impact audio cue")
	var captured_pos: Vector2 = trap_pos + Vector2(0.0, -15.0)
	_expect(_get_vector2(capture_result.get("ball_pos", Vector2.ZERO), Vector2.ZERO).distance_to(captured_pos) <= 0.001, "captured bowling trap ball should lock above the trap")
	scene.merge(capture_result, true)
	var captured_traps: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", []))
	_expect(captured_traps.size() == 1 and str(_get_dict(captured_traps[0]).get("state", "")) == "capturing", "bowling trap should expose the capture animation state")

	var release_result: Dictionary = {}
	for i in range(90):
		var frame_result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), scene, deps)
		if not frame_result.is_empty():
			scene.merge(frame_result, true)
		if bool(frame_result.get("commando_bowling_trap_released", false)):
			release_result = frame_result
			break
	_expect(bool(release_result.get("commando_bowling_trap_released", false)), "bowling trap should relaunch the ball after the Python 90-frame capture")
	var launch_vel: Vector2 = _get_vector2(release_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(launch_vel.y < 0.0 and launch_vel.length() >= 27.9, "bowling trap relaunch should fire upward at 4x the captured speed")
	_expect(not bool(release_result.get("skip_ball_motion_step", true)), "bowling trap release should clear the held-ball motion skip")
	_expect(bool(release_result.get("commando_bowling_trap_guard_armed", false)), "bowling trap release should arm the next boss-guard collision")
	_expect(str(release_result.get("commando_bowling_trap_guard_source", "")).begins_with("commando_bowling_trap_guard_"), "bowling trap release should expose a stable guard status source")
	_expect(is_equal_approx(float(release_result.get("commando_bowling_trap_guard_knockback_power", 0.0)), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER), "bowling trap release should expose dynamite-grade guard knockback metadata")
	_expect(is_equal_approx(float(release_result.get("commando_bowling_trap_guard_stun_frames", 0.0)), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES), "bowling trap release should expose the guard stun metadata")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", [])).is_empty(), "released bowling trap should remove the used trap body")
	_expect(not _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", [])).is_empty(), "bowling trap launch should leave a clamp burst effect")
	_expect(_get_array(audio.impact_calls).count("bowling_trap") == 1, "bowling trap release should not replay the pre-launch snap cue")
	_expect(_get_array(ball_effects.pulses).size() >= 2, "bowling trap capture and release should pulse the ball renderer")
	_verify_bowling_trap_guard_handoff(release_result, runtime, deps)

	var controller_setup: Dictionary = _build_setup("bowling_trap")
	var controller_runtime: Object = controller_setup.get("runtime", null)
	var controller_deps: Dictionary = controller_setup.get("deps", {}).duplicate(true)
	var controller_config: Dictionary = _fire_config()
	controller_runtime.update_input({"action_pressed": true}, 500.0, controller_config, controller_setup.get("deps", {}))
	for i in range(49):
		controller_runtime.update_effects(1.0, Time.get_ticks_msec(), controller_config, controller_setup.get("deps", {}))
	var controller_trap: Dictionary = _get_dict(_get_array(controller_runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", []))[0])
	var controller_trap_pos: Vector2 = _get_vector2(controller_trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	controller_config["ball_active"] = true
	controller_config["ball_size"] = 28.6
	controller_config["ball_pos"] = controller_trap_pos + Vector2(0.0, -2.0)
	controller_config["ball_vel"] = Vector2(0.0, 7.0)
	controller_config["dash_snapshot"] = {"max_tokens": 1, "tokens": 1}
	controller_deps["commando_firearm_runtime"] = controller_runtime
	var effects_controller := BattleEffectsUpdateController.new()
	var controller_capture: Dictionary = effects_controller.update(1.0 / 60.0, controller_config, controller_deps)
	_expect(bool(controller_capture.get("commando_bowling_trap_captured", false)), "battle effects controller should return the bowling trap ball-capture result")
	_expect(bool(controller_capture.get("skip_ball_motion_step", false)), "battle effects controller should preserve bowling trap motion-skip ownership")


func _verify_bowling_trap_guard_handoff(release_result: Dictionary, runtime: Object, deps: Dictionary) -> void:
	var owner := FakeOwner.new()
	var applier := BattleSceneEffectsUpdateResultApplier.new()
	applier.apply_effects_result(owner, release_result)
	_expect(owner.commando_bowling_trap_guard_armed, "effects result applier should persist armed bowling-trap guard state")
	_expect(is_equal_approx(owner.commando_bowling_trap_guard_knockback_power, CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER), "effects result applier should persist bowling-trap guard knockback")
	_expect(is_equal_approx(owner.commando_bowling_trap_guard_stun_frames, CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES), "effects result applier should persist bowling-trap guard stun duration")

	var status_effect_state := FakeStatusEffectState.new()
	var ai_state := FakeAiState.new()
	var boss_hit_handler := PaddleBounceBossPostHitHandler.new()
	var boss_context: Dictionary = _fire_config()
	boss_context.merge(release_result, true)
	boss_context["boss_y"] = 25.0
	boss_context["ball_size"] = 28.6
	boss_context["boss_pos"] = Vector2(328.0, 25.0)
	boss_context["boss_paddle_width"] = 100.0
	var restored_speed: float = float(release_result.get("commando_bowling_trap_guard_restore_speed", 0.0))
	var audio: Object = deps.get("audio", null)
	var trap_audio_count_before_guard: int = _get_array(audio.impact_calls).count("bowling_trap") if audio != null else 0
	var guard_deps: Dictionary = deps.duplicate(true)
	guard_deps["status_effect_state"] = status_effect_state
	guard_deps["ai_state"] = ai_state
	guard_deps["commando_firearm_runtime"] = runtime
	var guard_result: Dictionary = boss_hit_handler.apply(
		Vector2(392.0, 60.0),
		Vector2(6.0, 28.0),
		0.0,
		0.0,
		false,
		false,
		false,
		boss_context,
		guard_deps,
		null
	)
	_expect(bool(guard_result.get("commando_bowling_trap_guard_hit", false)), "boss post-hit handler should consume armed bowling-trap guard state")
	_expect(not bool(guard_result.get("commando_bowling_trap_guard_armed", true)), "boss post-hit handler should clear bowling-trap guard state after one hit")
	_expect(not bool(runtime.is_bowling_trap_guard_armed()), "runtime should consume bowling-trap guard state after the boss guard hit")
	_expect(is_equal_approx(abs(float(guard_result.get("boss_vel", 0.0))), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER), "bowling-trap boss guard should apply dynamite-grade knockback power")
	_expect(is_equal_approx(_get_vector2(guard_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length(), restored_speed), "bowling-trap boss guard should restore the ball to the reduced original speed")
	if audio != null:
		_expect(_get_array(audio.impact_calls).count("bowling_trap") == trap_audio_count_before_guard, "bowling-trap boss guard should not replay the capture/launch audio sequence")
	_expect(ai_state.knockback_calls == 0, "bowling-trap boss guard should avoid double AI knockback when shared status owns the stun movement")
	var status_calls: Array = _get_array(status_effect_state.get_calls_for_source("commando_bowling_trap_guard"))
	_expect(status_calls.size() == 1, "bowling-trap boss guard should apply one shared boss status")
	_expect(str(_get_dict(status_calls[0]).get("target", "")) == "boss", "bowling-trap guard status should target the boss")
	_expect(str(_get_dict(status_calls[0]).get("status_id", "")) == "stun", "bowling-trap guard status should be a stun")
	_expect(is_equal_approx(float(_get_dict(status_calls[0]).get("duration_frames", 0.0)), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_STUN_FRAMES), "bowling-trap guard stun should keep the 1s duration")
	var status_data: Dictionary = _get_dict(_get_dict(status_calls[0]).get("data", {}))
	_expect(is_equal_approx(abs(float(status_data.get("knockback_vel", 0.0))), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_POWER), "bowling-trap guard status should carry dynamite-grade knockback velocity")
	_expect(is_equal_approx(float(status_data.get("knockback_frames", 0.0)), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_FRAMES), "bowling-trap guard status should use the dynamite knockback motion window")
	_expect(is_equal_approx(float(status_data.get("knockback_decay_per_frame", 0.0)), CommandoFirearmRuntime.BOWLING_TRAP_GUARD_KNOCKBACK_DECAY), "bowling-trap guard status should decay through the active-item knockback feel")


func _verify_bowling_trap_round_carryover() -> void:
	var setup: Dictionary = _build_setup("bowling_trap")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	var fire_result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(fire_result.get("fired", false)), "round carryover setup should install a bowling trap")
	for i in range(49):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	runtime.reset_round(deps)
	var waiting_traps: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", []))
	_expect(waiting_traps.size() == 1, "round reset should preserve an installed bowling trap for the next round")
	_expect(str(_get_dict(waiting_traps[0]).get("state", "")) == "waiting", "carried bowling trap should be ready in the next round")

	var capture_setup: Dictionary = _build_setup("bowling_trap")
	var capture_runtime: Object = capture_setup.get("runtime", null)
	var capture_deps: Dictionary = capture_setup.get("deps", {})
	var capture_config: Dictionary = _fire_config()
	capture_runtime.update_input({"action_pressed": true}, 500.0, capture_config, capture_deps)
	for i in range(49):
		capture_runtime.update_effects(1.0, Time.get_ticks_msec(), capture_config, capture_deps)
	var trap: Dictionary = _get_dict(_get_array(capture_runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", []))[0])
	var trap_pos: Vector2 = _get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	capture_config["ball_active"] = true
	capture_config["ball_size"] = 28.6
	capture_config["ball_pos"] = trap_pos + Vector2(0.0, -2.0)
	capture_config["ball_vel"] = Vector2(0.0, 7.0)
	var capture_result: Dictionary = capture_runtime.update_effects(1.0, Time.get_ticks_msec(), capture_config, capture_deps)
	_expect(bool(capture_result.get("commando_bowling_trap_captured", false)), "round carryover setup should enter the capture state")
	capture_runtime.reset_round(capture_deps)
	var carried_capture_traps: Array = _get_array(capture_runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", []))
	_expect(carried_capture_traps.size() == 1, "round reset should preserve a trap that was holding the old round's ball")
	var carried_capture_trap: Dictionary = _get_dict(carried_capture_traps[0])
	_expect(str(carried_capture_trap.get("state", "")) == "waiting", "round reset should release old captured-ball ownership and keep the trap installed")
	_expect(is_equal_approx(float(carried_capture_trap.get("captured_original_speed", -1.0)), 0.0), "carried trap should not preserve old captured ball speed")

	capture_runtime.reset_round({"preserve_bowling_traps": false})
	_expect(_get_array(capture_runtime.get_actor_draw_context().get("commando_firearm_bowling_traps", [])).is_empty(), "explicit full cleanup should still clear bowling traps")


func _verify_suicide_drone_direct_control_lifecycle() -> void:
	var setup: Dictionary = _build_setup("suicide_drone")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var deps: Dictionary = setup.get("deps", {})
	var audio: Object = setup.get("audio", null)
	var config: Dictionary = _fire_config()

	var launch: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		config,
		deps
	)
	_expect(bool(launch.get("fired", false)), "suicide drone fresh action edge should launch one direct-control drone")
	_expect(int(launch.get("ammo_current", -1)) == 3, "suicide drone should spend one of the Python 4 drones")
	_expect(int(launch.get("ammo_max", -1)) == 4, "suicide drone launch result should expose Python 4-drone max ammo")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "suicide drone should remain fire-capable while drones remain")
	_expect(bool(runtime.is_player_control_locked()), "active suicide drone should lock normal player control")
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 0.0), "active suicide drone should freeze normal player movement")
	_expect(audio.suicide_drone_launch_calls == 1, "suicide drone launch should start the dedicated loop cue")
	var launch_context: Dictionary = runtime.get_actor_draw_context()
	var launch_projectiles: Array = _get_array(launch_context.get("commando_firearm_projectiles", []))
	_expect(launch_projectiles.size() == 1, "suicide drone launch should create one drone projectile")
	var drone: Dictionary = _get_dict(launch_projectiles[0])
	var drone_pos: Vector2 = _get_vector2(drone.get("pos", Vector2.ZERO), Vector2.ZERO)
	_expect(str(drone.get("kind", "")) == "drone" and bool(drone.get("manual_control", false)), "suicide drone projectile should be manually controlled, not homing")
	_expect(_get_vector2(drone.get("size", Vector2.ZERO), Vector2.ZERO) == Vector2(48.0, 48.0), "suicide drone should use the Python 48x48 body")
	_expect(is_equal_approx(drone_pos.x, 379.5) and is_equal_approx(drone_pos.y, 624.0), "suicide drone should spawn above the player paddle like Python")
	_expect(is_equal_approx(float(drone.get("grace_timer_frames", 0.0)), 6.0), "suicide drone should start with the Python 6-frame grace window")

	var held: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": false, "right_pressed": true, "up_pressed": true},
		500.0,
		config,
		deps
	)
	_expect(bool(held.get("drone_active", false)), "held suicide drone input should steer the active drone")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "held suicide drone input should not consume another drone")
	runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var steered_projectile: Dictionary = _get_dict(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))[0])
	var steered_pos: Vector2 = _get_vector2(steered_projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var steered_velocity: Vector2 = _get_vector2(steered_projectile.get("velocity", Vector2.ZERO), Vector2.ZERO)
	_expect(steered_velocity.length() > 0.0 and steered_velocity.length() <= 14.0, "suicide drone steering should accelerate within the Python max speed")
	_expect(steered_pos.x > drone_pos.x and steered_pos.y < drone_pos.y, "suicide drone steering should move along the held input vector")

	for _i in range(6):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	runtime.update_input({"action_pressed": false, "action_just_released": true}, 500.0, config, deps)
	var manual: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		config,
		deps
	)
	_expect(bool(manual.get("commando_suicide_drone_detonated", false)), "suicide drone fresh action edge after grace should manually detonate")
	_expect(str(manual.get("commando_suicide_drone_reason", "")) == "manual", "manual suicide drone detonation should preserve its reason")
	_expect(is_equal_approx(float(manual.get("commando_suicide_drone_cooldown_frames", 0.0)), 90.0), "suicide drone detonation should start the Python 90-frame cooldown")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "detonated suicide drone should remove the drone body")
	var active_item_runtime: Object = setup.get("active_item_runtime", null)
	_expect(_get_array(active_item_runtime.molotov_fire_zone_calls).size() == 1, "suicide drone detonation should leave a molotov fire-zone effect")
	_expect(audio.suicide_drone_explosion_calls == 1, "suicide drone detonation should play the explosion cue")
	_expect(audio.suicide_drone_stop_calls >= 1, "suicide drone detonation should stop the loop cue")

	var boss_setup: Dictionary = _build_setup("suicide_drone")
	var boss_runtime: Object = boss_setup.get("runtime", null)
	var boss_deps: Dictionary = boss_setup.get("deps", {})
	var boss_status: Object = boss_setup.get("status_effect_state", null)
	var boss_config: Dictionary = _fire_config()
	boss_config["ball_active"] = false
	boss_config["boss_pos"] = Vector2(329.5, 604.0)
	boss_config["boss_paddle_width"] = 100.0
	boss_config["boss_hitbox_height"] = 40.0
	_expect(bool(boss_runtime.update_input({"action_pressed": true, "action_just_pressed": true}, 500.0, boss_config, boss_deps).get("fired", false)), "suicide drone should launch for boss-contact detonation smoke")
	var boss_detonation: Dictionary = {}
	for _i in range(6):
		var boss_frame: Dictionary = boss_runtime.update_effects(1.0, Time.get_ticks_msec(), boss_config, boss_deps)
		if bool(boss_frame.get("commando_suicide_drone_detonated", false)):
			boss_detonation = boss_frame
			break
	_expect(str(boss_detonation.get("commando_suicide_drone_reason", "")) == "boss_hit", "suicide drone should detonate when its body reaches the boss after grace")
	var boss_calls: Array = _get_array(boss_status.get_calls_for_source("commando_firearm_suicide_drone"))
	_expect(not boss_calls.is_empty(), "suicide drone boss detonation should apply shared boss status")

	var wall_setup: Dictionary = _build_setup("suicide_drone")
	var wall_runtime: Object = wall_setup.get("runtime", null)
	var wall_deps: Dictionary = wall_setup.get("deps", {})
	var wall_config: Dictionary = _fire_config()
	wall_config["ball_active"] = false
	wall_config["boss_pos"] = Vector2(40.0, 62.0)
	_expect(bool(wall_runtime.update_input({"action_pressed": true, "action_just_pressed": true}, 500.0, wall_config, wall_deps).get("fired", false)), "suicide drone should launch for top-wall detonation smoke")
	for _i in range(6):
		wall_runtime.update_effects(1.0, Time.get_ticks_msec(), wall_config, wall_deps)
	var wall_detonation: Dictionary = {}
	for _i in range(80):
		wall_runtime.update_input({"action_pressed": false, "up_pressed": true}, 500.0, wall_config, wall_deps)
		var wall_frame: Dictionary = wall_runtime.update_effects(1.0, Time.get_ticks_msec(), wall_config, wall_deps)
		if bool(wall_frame.get("commando_suicide_drone_detonated", false)):
			wall_detonation = wall_frame
			break
	_expect(str(wall_detonation.get("commando_suicide_drone_reason", "")) == "boss_back_wall", "suicide drone should detonate on top-wall contact")


func _verify_suicide_drone_ball_boost_and_boss_restore() -> void:
	var setup: Dictionary = _build_setup("suicide_drone")
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = _fire_config()
	var launch: Dictionary = runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		config,
		deps
	)
	_expect(bool(launch.get("fired", false)), "suicide drone should launch for ball-boost smoke")
	for _i in range(6):
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	var drone: Dictionary = _get_dict(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", []))[0])
	var drone_pos: Vector2 = _get_vector2(drone.get("pos", Vector2.ZERO), Vector2.ZERO)
	var scene: Dictionary = config.duplicate(true)
	scene["ball_active"] = true
	scene["ball_size"] = 28.6
	scene["ball_pos"] = drone_pos
	scene["ball_vel"] = Vector2(0.0, -9.0)
	scene["ball_base_speed"] = 8.0
	var boost_result: Dictionary = runtime.update_effects(1.0, Time.get_ticks_msec(), scene, deps)
	_expect(bool(boost_result.get("commando_suicide_drone_detonated", false)), "suicide drone should detonate on ball contact after grace")
	_expect(str(boost_result.get("commando_suicide_drone_reason", "")) == "ball_hit", "suicide drone ball contact should preserve the ball-hit reason")
	_expect(bool(boost_result.get("commando_suicide_drone_ball_boosted", false)), "suicide drone ball contact should expose boost metadata")
	var boosted_vel: Vector2 = _get_vector2(boost_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(boosted_vel.y < 0.0 and is_equal_approx(boosted_vel.length(), 27.0), "suicide drone should relaunch the ball upward at 3x speed")
	_expect(bool(boost_result.get("commando_suicide_drone_ball_boost_active", false)), "suicide drone ball boost should stay active until the boss returns it")
	_expect(is_equal_approx(float(boost_result.get("commando_suicide_drone_ball_restore_speed", 0.0)), 9.0), "suicide drone should preserve the original ball speed for boss restore")
	_expect(is_equal_approx(float(boost_result.get("commando_suicide_drone_ball_boosted_speed", 0.0)), 27.0), "suicide drone should expose the boosted speed metadata")
	_expect(bool(boost_result.get("speed_limit_disabled", false)), "suicide drone ball boost should disable speed caps until the boss returns it")

	var owner := FakeOwner.new()
	var applier := BattleSceneEffectsUpdateResultApplier.new()
	applier.apply_effects_result(owner, boost_result)
	_expect(owner.commando_suicide_drone_ball_boost_active, "effects result applier should persist suicide-drone boost active state")
	_expect(is_equal_approx(owner.commando_suicide_drone_ball_restore_speed, 9.0), "effects result applier should persist suicide-drone restore speed")
	_expect(is_equal_approx(owner.commando_suicide_drone_ball_boosted_speed, 27.0), "effects result applier should persist suicide-drone boosted speed metadata")

	var boss_handler := PaddleBounceBossPostHitHandler.new()
	var boss_context: Dictionary = _fire_config()
	boss_context["boss_y"] = 25.0
	boss_context["boss_pos"] = Vector2(328.0, 25.0)
	boss_context["boss_paddle_width"] = 100.0
	boss_context["ball_size"] = 28.6
	boss_context["commando_suicide_drone_ball_boost_active"] = true
	boss_context["commando_suicide_drone_ball_restore_speed"] = 9.0
	boss_context["commando_suicide_drone_ball_boosted_speed"] = 27.0
	var boss_result: Dictionary = boss_handler.apply(
		Vector2(392.0, 60.0),
		boosted_vel,
		0.0,
		0.0,
		false,
		false,
		false,
		boss_context,
		deps,
		null
	)
	_expect(bool(boss_result.get("commando_suicide_drone_ball_boost_consumed", false)), "boss post-hit handler should consume suicide-drone boost state")
	_expect(not bool(boss_result.get("commando_suicide_drone_ball_boost_active", true)), "boss post-hit handler should clear suicide-drone boost active state")
	_expect(is_equal_approx(float(boss_result.get("commando_suicide_drone_ball_restore_speed", -1.0)), 0.0), "boss post-hit handler should clear suicide-drone restore speed")
	_expect(is_equal_approx(float(boss_result.get("commando_suicide_drone_ball_boosted_speed", -1.0)), 0.0), "boss post-hit handler should clear suicide-drone boosted speed metadata")
	_expect(not bool(boss_result.get("speed_limit_disabled", true)), "boss post-hit handler should restore the speed cap after suicide-drone boost")
	_expect(is_equal_approx(_get_vector2(boss_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).length(), 9.0), "boss post-hit handler should restore the boosted ball to original speed")


func _verify_removed_suicide_drone_lingering_bridges() -> void:
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	for bridge_name in [
		"_spawn_weapon_lingering_effect",
		"_trigger_active_item_molotov_fire_zone",
	]:
		_expect(runtime_source.find("func %s(" % bridge_name) == -1, "runtime should not keep suicide-drone lingering bridge %s" % bridge_name)


func _verify_non_fire_inputs_do_not_spawn_vfx() -> void:
	var setup: Dictionary = _build_setup("net_gun")
	var runtime: Object = setup.get("runtime", null)
	var result: Dictionary = runtime.update_input(
		{"action_pressed": true, "down_pressed": true},
		500.0,
		_fire_config(),
		setup.get("deps", {})
	)
	_expect(result.is_empty(), "supply-drop hold input should not fire a weapon")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "suppressed hold input should not create projectile VFX")


func _verify_serve_wait_fire_suppression_requires_release() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var deps: Dictionary = setup.get("deps", {})
	var round_state := FakeRoundState.new()
	deps["round_state"] = round_state
	var fire_config: Dictionary = _fire_config()

	round_state.waiting_for_serve = true
	var waiting_press: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, fire_config, deps)
	_expect(waiting_press.is_empty(), "serve-wait press should suppress Commando firearm input")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "serve-wait press should not spend weapon ammo")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "serve-wait press should not spawn projectile VFX")

	round_state.waiting_for_serve = false
	var held_after_wait: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, fire_config, deps)
	_expect(held_after_wait.is_empty(), "held fire after serve wait should stay suppressed until release")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "held fire after serve wait should not spend ammo")

	var release_after_wait: Dictionary = runtime.update_input({"action_pressed": false}, 500.0, fire_config, deps)
	_expect(release_after_wait.is_empty(), "serve-wait release should only clear suppression")

	var fresh_press: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, fire_config, deps)
	_expect(bool(fresh_press.get("fired", false)), "fresh fire after serve-wait release should fire normally")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).size() == 1, "fresh fire after serve-wait release should spawn projectile VFX")

	var config_setup: Dictionary = _build_setup("net_gun")
	var config_wait: Dictionary = _fire_config()
	config_wait["waiting_for_serve"] = true
	var config_wait_result: Dictionary = config_setup.get("runtime", null).update_input(
		{"action_pressed": true},
		500.0,
		config_wait,
		config_setup.get("deps", {})
	)
	_expect(config_wait_result.is_empty(), "waiting_for_serve config flag should also suppress Commando firearm input")


func _verify_cooldown_and_switch_suppression_do_not_spend_or_spawn() -> void:
	var setup: Dictionary = _build_setup("bazooka")
	var runtime: Object = setup.get("runtime", null)
	var controller: Object = setup.get("controller", null)
	var state: Object = setup.get("state", null)
	var skill_config: Object = setup.get("config", null)
	var deps: Dictionary = setup.get("deps", {})
	var fire_config: Dictionary = _fire_config()

	_expect(bool(runtime.update_input({"action_pressed": true}, 500.0, fire_config, deps).get("fired", false)), "first bazooka shot should fire before cooldown test")
	_expect(bool(controller.refill_current_permanent()), "bazooka should refill for cooldown block check")
	runtime.reset()
	var blocked: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, fire_config, deps)
	_expect(bool(blocked.get("fire_failed", false)), "configured cooldown should block a refilled bazooka")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "cooldown block should not spend ammo")
	_expect(_get_array(runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "cooldown block should not create projectile VFX")
	_expect(float(state.get_cooldown_remaining("bazooka", Time.get_ticks_msec(), skill_config.get_cooldown_seconds("bazooka"))) > 0.0, "cooldown state should remain active")

	var switched_setup: Dictionary = _build_setup("net_gun")
	var switched_runtime: Object = switched_setup.get("runtime", null)
	var switched_controller: Object = switched_setup.get("controller", null)
	switched_controller.last_switch_msec = Time.get_ticks_msec()
	var suppressed: Dictionary = switched_runtime.update_input({"action_pressed": true}, 500.0, fire_config, switched_setup.get("deps", {}))
	_expect(suppressed.is_empty(), "weapon switch grace should suppress immediate fire")
	_expect(bool(switched_controller.get_current_weapon_data().get("can_fire", false)), "switch suppression should not spend ammo")
	_expect(_get_array(switched_runtime.get_actor_draw_context().get("commando_firearm_projectiles", [])).is_empty(), "switch suppression should not spawn projectile VFX")


func _verify_firearm_fx_host_activation_does_not_emit_stale_particles() -> void:
	var host := Stage1CommandoFirearmFxHost.new()
	host.prewarm_node_pipeline()
	var inactive_status: Dictionary = host.get_debug_status()
	_expect(not bool(inactive_status.get("muzzle_particles_emitting", true)), "prewarmed firearm FX host should keep muzzle particles stopped")
	host.set_active(true)
	var bare_active_status: Dictionary = host.get_debug_status()
	_expect(not bool(bare_active_status.get("muzzle_particles_emitting", true)), "firearm FX host activation should not emit stale muzzle particles before anchor sync")
	_expect(not bool(bare_active_status.get("impact_particles_emitting", true)), "firearm FX host activation should not emit stale impact particles before anchor sync")

	var layout := {
		"game_offset": Vector2(8.0, 12.0),
		"render_scale": 1.5,
	}
	host.sync_state(
		{
			"muzzle_flashes": [{
				"pos": Vector2(100.0, 200.0),
				"direction": Vector2.UP,
				"radius": 16.0,
				"timer_frames": 8.0,
				"max_timer_frames": 8.0,
			}],
			"impact_flashes": [],
			"lingering_effects": [],
		},
		Vector2.ZERO,
		true,
		layout
	)
	var muzzle_status: Dictionary = host.get_debug_status()
	_expect(str(muzzle_status.get("anchor_source", "")) == "muzzle", "firearm FX host should anchor muzzle particles to the synced muzzle source")
	_expect(bool(muzzle_status.get("muzzle_particles_emitting", false)), "synced muzzle source should emit muzzle particles")
	_expect(host.position.is_equal_approx(Vector2(158.0, 312.0)), "firearm FX host should move to the muzzle anchor before particle emission is visible")

	host.sync_state(
		{
			"muzzle_flashes": [],
			"impact_flashes": [{
				"pos": Vector2(260.0, 180.0),
				"radius": 20.0,
				"timer_frames": 10.0,
				"max_timer_frames": 10.0,
			}],
			"lingering_effects": [],
		},
		Vector2.ZERO,
		true,
		layout
	)
	var impact_status: Dictionary = host.get_debug_status()
	_expect(str(impact_status.get("anchor_source", "")) == "impact", "firearm FX host should retarget to the impact source")
	_expect(not bool(impact_status.get("muzzle_particles_emitting", true)), "impact retarget should stop muzzle particles instead of leaving old muzzle sparks active")
	host.set_active(false)
	var cleared_status: Dictionary = host.get_debug_status()
	_expect(not bool(cleared_status.get("muzzle_particles_emitting", true)), "inactive firearm FX host should stop muzzle particles")
	_expect(not bool(cleared_status.get("impact_particles_emitting", true)), "inactive firearm FX host should stop impact particles")
	host.free()


func _verify_stage1_renderer_context_reader() -> void:
	var renderer: Object = Stage1CommandoFirearmRenderer.new()
	var items: Dictionary = renderer.build_draw_items({
		"selected_character_type": "soldier",
		"commando_firearm_projectiles": [{"pos": Vector2(10.0, 20.0), "kind": "bullet"}],
		"commando_firearm_muzzle_flashes": [{"pos": Vector2(10.0, 20.0)}],
		"commando_firearm_impact_flashes": [{"pos": Vector2(12.0, 18.0)}],
		"commando_firearm_lingering_effects": [{"pos": Vector2(20.0, 30.0), "kind": "net_field"}],
		"commando_firearm_shell_casings": [{"pos": Vector2(22.0, 44.0), "weapon_id": "ak47"}],
		"commando_firearm_pistol_feedbacks": [{"kind": "headshot", "text": "헤드샷!"}],
		"commando_firearm_pistol_state": {"shot_pending": true, "fire_delay_frames": 12.0},
		"commando_firearm_support_calls": [{"origin": Vector2(14.0, 26.0), "target": Vector2(20.0, 30.0)}],
		"commando_firearm_bowling_traps": [{"pos": Vector2(30.0, 40.0), "state": "waiting"}],
	})
	_expect(_get_array(items.get("projectiles", [])).size() == 1, "Stage1 firearm renderer should read projectile context")
	_expect(_get_array(items.get("muzzle_flashes", [])).size() == 1, "Stage1 firearm renderer should read muzzle context")
	_expect(_get_array(items.get("impact_flashes", [])).size() == 1, "Stage1 firearm renderer should read impact context")
	_expect(_get_array(items.get("lingering_effects", [])).size() == 1, "Stage1 firearm renderer should read lingering effect context")
	_expect(_get_array(items.get("shell_casings", [])).size() == 1, "Stage1 firearm renderer should read AK-47 shell casing context")
	_expect(_get_array(items.get("pistol_feedbacks", [])).size() == 1, "Stage1 firearm renderer should read pistol headshot/legshot feedback context")
	_expect(bool(_get_dict(items.get("pistol_state", {})).get("shot_pending", false)), "Stage1 firearm renderer should read pistol aim-delay state context")
	_expect(_get_array(items.get("support_calls", [])).size() == 1, "Stage1 firearm renderer should read fire-support call context")
	_expect(_get_array(items.get("bowling_traps", [])).size() == 1, "Stage1 firearm renderer should read bowling-trap context")


func _queue_and_resolve_pistol_shot(runtime: Object, deps: Dictionary, config: Dictionary) -> Dictionary:
	var queued: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, config, deps)
	_expect(bool(queued.get("fired", false)), "Commando pistol helper should fire immediately")
	_expect(not bool(queued.get("shot_queued", false)), "Commando pistol helper should not queue a ready shot")
	return queued


func _wait_pistol_ready(runtime: Object, deps: Dictionary, config: Dictionary) -> void:
	for _i in range(60):
		runtime.update_input({"action_pressed": false}, 500.0, config, deps)


func _build_setup(weapon_id: String) -> Dictionary:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var feedback := FakeFeedback.new()
	var impact_effects := FakeImpactEffects.new()
	var ball_effects := FakeBallEffects.new()
	var animation_state := FakeAnimationState.new()
	var audio := FakeAudio.new()
	var status_effect_state := FakeStatusEffectState.new()
	var ai_state := FakeAiState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	_expect(bool(config.unlock_and_equip_skill(weapon_id)), "%s should unlock for runtime setup" % weapon_id)
	controller.sync_equipped_permanent(config)
	_expect(bool(controller.set_current_weapon(weapon_id)), "%s should become selectable for runtime setup" % weapon_id)
	return {
		"runtime": runtime,
		"config": config,
		"state": state,
		"controller": controller,
		"feedback": feedback,
		"impact_effects": impact_effects,
		"ball_effects": ball_effects,
		"animation_state": animation_state,
		"audio": audio,
		"status_effect_state": status_effect_state,
		"ai_state": ai_state,
		"active_item_runtime": active_item_runtime,
		"deps": {
			"commando_weapon_controller": controller,
			"skill_state": state,
			"skill_config": config,
			"feedback": feedback,
			"impact_effects": impact_effects,
			"ball_effects": ball_effects,
			"animation_state": animation_state,
			"audio": audio,
			"status_effect_state": status_effect_state,
			"ai_state": ai_state,
			"active_item_runtime": active_item_runtime,
		},
	}


func _fire_config() -> Dictionary:
	return {
		"player_pos": Vector2(302.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(328.0, 62.0),
		"boss_vel": -2.5,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_has_hit_sprite": true,
		"width": 760.0,
		"height": 750.0,
	}


func _boss_center(config: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width: float = float(config.get("boss_paddle_width", 100.0))
	var boss_height: float = float(config.get("boss_hitbox_height", 40.0))
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)


func _ak47_base_aim_angle(config: Dictionary) -> float:
	var player_pos: Vector2 = _get_vector2(config.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_width: float = float(config.get("paddle_width", 155.0))
	var paddle_height: float = float(config.get("paddle_height", 50.0))
	var muzzle := Vector2(
		player_pos.x + paddle_width * 0.5,
		player_pos.y + min(paddle_height * 0.34, 18.0)
	)
	return (_boss_center(config) - muzzle).angle()


func _angle_delta(angle: float, reference: float) -> float:
	return atan2(sin(angle - reference), cos(angle - reference))


func _direct_projectile(weapon_id: String, pos: Vector2, velocity: Vector2) -> Dictionary:
	return {
		"id": hash(weapon_id),
		"weapon_id": weapon_id,
		"kind": weapon_id,
		"pos": pos,
		"velocity": velocity,
		"color": Color.WHITE,
	}


func _expected_net_gun_aim_origin(config: Dictionary) -> Vector2:
	return CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
		config,
		CommandoFirearmRuntime.COMMANDO_NET_GUN_FIRE_MUZZLE_SOURCE,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_SOURCE_CELL_SIZE,
		CommandoFirearmRuntime.COMMANDO_FIRE_SHEET_PLAYER_FOOT_Y_OFFSET
	)


func _get_runtime_projectile_impact_reason(projectile: Dictionary, context: Dictionary) -> String:
	return CommandoFirearmProjectileImpactState.get_impact_reason(
		projectile,
		context,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.FIELD_WIDTH
	)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _color_close(actual: Color, expected: Color, tolerance: float = 0.01) -> bool:
	return (
		abs(actual.r - expected.r) <= tolerance
		and abs(actual.g - expected.g) <= tolerance
		and abs(actual.b - expected.b) <= tolerance
		and abs(actual.a - expected.a) <= tolerance
	)


func _find_call_with_source_fragment(calls: Array, fragment: String) -> Dictionary:
	for value in calls:
		@warning_ignore("shadowed_variable_base_class")
		var call: Dictionary = _get_dict(value)
		if str(call.get("source", "")).find(fragment) >= 0:
			return call
	return {}


func _find_impact_flash(runtime: Object, weapon_id: String) -> Dictionary:
	var flashes: Array = _get_array(runtime.get_actor_draw_context().get("commando_firearm_impact_flashes", []))
	for index in range(flashes.size() - 1, -1, -1):
		var flash: Dictionary = _get_dict(flashes[index])
		if str(flash.get("weapon_id", "")) == weapon_id:
			return flash
	return {}


func _has_lingering_effect_for_weapon(runtime: Object, weapon_id: String) -> bool:
	for value in _get_array(runtime.get_actor_draw_context().get("commando_firearm_lingering_effects", [])):
		if str(_get_dict(value).get("weapon_id", "")) == weapon_id:
			return true
	return false


func _has_bazooka_explosion_shake(feedback: Object) -> bool:
	if feedback == null:
		return false
	var expected_amount: float = ActiveItemThrowController.GRENADE_SCREEN_SHAKE_AMOUNT
	var expected_intensity: float = ActiveItemThrowController.GRENADE_SCREEN_SHAKE_INTENSITY * 0.5
	for value in _get_array(feedback.get("shake_entries")):
		var entry: Dictionary = _get_dict(value)
		if (
			is_equal_approx(float(entry.get("amount", 0.0)), expected_amount)
			and is_equal_approx(float(entry.get("intensity", 0.0)), expected_intensity)
		):
			return true
	return false


# Late-dissolve nets collapse the hull below the jitter amplitude and can
# self-intersect; the fill gate must reject those instead of letting
# draw_colored_polygon spam "Invalid polygon data" every frame near expiry
# (137 errors/session in the 2026-06-11 stage 1-5 commando run).
func _verify_net_field_fill_guard_rejects_degenerate_polygon() -> void:
	var bowtie := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(10.0, 10.0), Vector2(10.0, 0.0), Vector2(0.0, 10.0),
	])
	_expect(
		not Stage1CommandoFirearmRenderer.can_fill_polygon(bowtie),
		"self-intersecting net hull should be rejected by the fill gate"
	)
	var ring := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(20.0, 0.0), Vector2(24.0, 12.0), Vector2(10.0, 20.0), Vector2(-4.0, 12.0),
	])
	_expect(
		Stage1CommandoFirearmRenderer.can_fill_polygon(ring),
		"a simple net hull should still pass the fill gate"
	)
	_expect(
		not Stage1CommandoFirearmRenderer.can_fill_polygon(PackedVector2Array([Vector2.ZERO, Vector2.ONE])),
		"a sub-triangle point set should be rejected by the fill gate"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
