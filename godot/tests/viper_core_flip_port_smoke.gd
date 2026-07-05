extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const EnergyBallFxHost := preload("res://scripts/ball/energy_ball_fx_host.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"action_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeDashState:
	var snapshot := {
		"active": false,
		"recovering": false,
		"is_half": false,
	}
	var cancelled := 0

	func get_snapshot() -> Dictionary:
		return snapshot

	func cancel_until_key_release() -> void:
		cancelled += 1
		snapshot["active"] = false
		snapshot["recovering"] = false


class FakeSkillConfig:
	var extra_equipped: Array = []
	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name in ["core_flip", "marshal_kick", "dark_blade"] or skill_name in extra_equipped

	func get_skill_cost(skill_name: String) -> float:
		if skill_name == "core_flip":
			return 120.0
		if skill_name == "marshal_kick":
			return 80.0
		if skill_name == "dark_blade":
			return 150.0
		return 0.0


class FakeSmasherSkillConfig:
	func is_skill_equipped(_skill_name: String) -> bool:
		return false

	func get_skill_cost(_skill_name: String) -> float:
		return 0.0


class FakeSkillState:
	var triggered: Array = []

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, _skill_config: Object) -> void:
		triggered.append(skill_name)

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakeAudio:
	var spin := 0
	var hwarang := 0
	var backstep := 0
	var marshal := 0
	var guard_knockback := 0

	func play_viper_blade_spin() -> void:
		spin += 1

	func play_viper_hwarang_kick() -> void:
		hwarang += 1

	func play_viper_backstep() -> void:
		backstep += 1

	func play_viper_marshal_kick() -> void:
		marshal += 1

	func play_viper_kick_guard_knockback() -> void:
		guard_knockback += 1


class FakeFeedback:
	var shakes := 0

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeAiState:
	var last_knockback_velocity := 0.0
	var last_knockback_frames := 0.0
	var last_knockback_decay := 0.0
	var last_replace_current := false

	func start_paddle_hit_knockback(velocity: float, frames: float = 36.0, decay_per_frame: float = 0.88, replace_current: bool = true) -> void:
		last_knockback_velocity = velocity
		last_knockback_frames = frames
		last_knockback_decay = decay_per_frame
		last_replace_current = replace_current


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakePerkState:
	var gold := 0
	var levels := {"kick_enhance": 0}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeStageBackground:
	var absorbed := 0

	func absorb_chaos_spear_objects(_center: Vector2, _radius: float, _deps: Dictionary = {}) -> Array:
		absorbed += 1
		return []


class FakeBallEffects:
	var pulses := 0
	var last_pos := Vector2.ZERO
	var last_velocity := Vector2.ZERO
	var last_intensity := 0.0
	var last_kind := ""

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float = 0.0, kind: String = "hit") -> void:
		pulses += 1
		last_pos = pos
		last_velocity = velocity
		last_intensity = intensity
		last_kind = kind


class FakeOwner:
	var selected_character_type := "viper"
	var runtime_accessory_slot_bonus := 0
	var runtime_paddle_scale := 1.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false


class RealViperRegistry:
	var perk_state: Object
	var skill_config: Object

	func _init(new_perk_state: Object, new_skill_config: Object) -> void:
		perk_state = new_perk_state
		skill_config = new_skill_config

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return perk_state
			"viper_skill_config":
				return skill_config
		return null


class FakeBallDepsRegistry:
	var instances: Dictionary = {}

	func _init() -> void:
		instances = {
			"smasher_skill_config": FakeSmasherSkillConfig.new(),
			"smasher_skill_state": FakeSkillState.new(),
			"viper_skill_config": FakeSkillConfig.new(),
			"viper_skill_state": FakeSkillState.new(),
			"viper_skill_runtime": ViperSkillRuntime.new(),
			"smasher_dash_state": FakeDashState.new(),
			"runtime_perk_state": FakePerkState.new(),
		}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_test_core_flip_unlock_catalog_wiring()
	_test_core_flip_energy_ball_fx_classification()
	_test_energy_ball_fx_host_stays_shell_driven()
	_test_ball_dependency_context_routes_viper_skill_config()
	_test_half_dash_does_not_arm_core_flip()
	_test_post_dash_recovery_arms_core_flip()
	_test_core_flip_dynamic_ball_prep_retime()
	_test_hwarang_followup_marshal_dynamic_prep_retime()
	_test_core_flip_runtime()
	_test_shadow_step_blocked_after_hwarang_chain()
	print("viper_core_flip_port_smoke: ok")
	quit(0)


func _test_core_flip_unlock_catalog_wiring() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var perk_state: Object = RuntimePerkState.new()
	var skill_config: Object = ViperSkillConfig.new()
	var owner := FakeOwner.new()
	var registry := RealViperRegistry.new(perk_state, skill_config)
	var unlock_data: Dictionary = catalog.get_perk_data("core_flip")
	_expect(not unlock_data.is_empty(), "core_flip should exist as the Hwarang Kick unlock perk")
	_expect(str(unlock_data.get("unlocks_skill", "")) == "core_flip", "core_flip perk should unlock the runtime core_flip orb")
	_expect(not skill_config.is_skill_equipped("core_flip"), "core_flip should not be equipped before unlock")
	unlock_data["id"] = "core_flip"
	_expect(perk_state.apply_choice(unlock_data, owner, registry), "selecting core_flip should apply cleanly")
	_expect(perk_state.get_runtime_skill_level("core_flip") == 1, "core_flip unlock should set runtime perk level")
	_expect(skill_config.is_skill_equipped("core_flip"), "core_flip unlock should equip Hwarang Kick")


func _test_ball_dependency_context_routes_viper_skill_config() -> void:
	var registry := FakeBallDepsRegistry.new()
	var deps: Dictionary = BallDependencyContext.new().build_update_deps(registry)
	_expect(deps.get("viper_skill_config", null) == registry.instances["viper_skill_config"], "ball update deps should carry Viper skill config")
	_expect(deps.get("viper_skill_state", null) == registry.instances["viper_skill_state"], "ball update deps should carry Viper skill state")
	var runtime: Object = deps["viper_skill_runtime"]
	var dash_state: Object = deps["dash_state"]
	var player_pos := Vector2(302.5, 680.0)
	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = false
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos + Vector2(90.0, 0.0), deps)
	runtime.register_player_ball_contact(deps, _base_config())
	_expect(bool(runtime.get_snapshot().get("core_flip_ready", false)), "ball collision deps should open Hwarang Kick with Viper config even when generic skill_config is Smasher")


func _test_core_flip_energy_ball_fx_classification() -> void:
	_expect("viper_core_flip" in EnergyBallFxHost.HIT_BURST_PREWARM_KINDS, "Hwarang Kick hit burst should be prewarmed with the other Viper kick bursts")
	_expect(EnergyBallFxHost._is_heavy_hit_kind("viper_core_flip"), "Hwarang Kick hit pulse should use heavy Viper kick particle density")
	_expect(EnergyBallFxHost._get_burst_particle_color("viper_core_flip").r > 0.80, "Hwarang Kick hit burst should use the Viper kick magenta palette")


func _test_energy_ball_fx_host_stays_shell_driven() -> void:
	var host: Node = EnergyBallFxHost.new()
	host.set_active(true)
	_expect(not host.is_processing(), "EnergyBallFxHost should not run an independent _process loop")
	host.sync_state(Vector2.ZERO, 1.0, Vector2(16.0, 0.0), false, true)
	_expect(not host.is_processing(), "EnergyBallFxHost sync should stay driven by the battle shell")
	host.tear_down()
	host.free()


func _test_half_dash_does_not_arm_core_flip() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps := _make_deps()
	var dash_state: Object = deps["dash_state"]
	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = true
	var player_pos := Vector2(302.5, 680.0)
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos, deps)
	runtime.register_player_ball_contact(deps, _base_config())
	_expect(not bool(runtime.get_snapshot().get("core_flip_ready", true)), "half dash ball hits should not open Hwarang Kick")


func _test_post_dash_recovery_arms_core_flip() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps := _make_deps()
	var dash_state: Object = deps["dash_state"]
	var player_pos := Vector2(302.5, 680.0)
	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = false
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos + Vector2(90.0, 0.0), deps)
	dash_state.snapshot["active"] = false
	dash_state.snapshot["recovering"] = true
	runtime.register_player_ball_contact(deps, _base_config())
	_expect(bool(runtime.get_snapshot().get("core_flip_ready", false)), "post-dash recovery hit should open Hwarang Kick like the Python 0.4s window")


func _test_core_flip_dynamic_ball_prep_retime() -> void:
	var fast_setup: Dictionary = _start_core_flip_prep_case({
		"ai_mode": "junior",
		"ball_pos": Vector2(620.0, 350.0),
		"ball_vel": Vector2(0.0, 18.0),
	})
	_advance_core_flip_frames(fast_setup, 50)
	var fast_runtime: Object = fast_setup.get("runtime", null)
	_expect(fast_runtime != null and int(fast_runtime.core_flip_attack_phase) == 2, "fast descending ball should shorten Hwarang wall prep regardless of league")

	var slow_setup: Dictionary = _start_core_flip_prep_case({
		"ai_mode": "mythic league",
		"ball_vel": Vector2(0.0, -8.0),
	})
	_advance_core_flip_frames(slow_setup, 60)
	var slow_runtime: Object = slow_setup.get("runtime", null)
	_expect(slow_runtime != null and int(slow_runtime.core_flip_attack_phase) == 1, "slow upward ball should keep the original Hwarang wall prep even in mythic league")
	_advance_core_flip_frames(slow_setup, 10)
	_expect(int(slow_runtime.core_flip_attack_phase) == 2, "slow upward Hwarang prep should still finish on the original wall timing")


func _test_hwarang_followup_marshal_dynamic_prep_retime() -> void:
	var fast_setup: Dictionary = _start_hwarang_followup_marshal_case({}, {
		"ball_pos": Vector2(620.0, 560.0),
		"ball_vel": Vector2(0.0, 18.0),
	})
	_advance_hwarang_followup_marshal_frames(fast_setup, 14)
	var fast_runtime: Object = fast_setup.get("runtime", null)
	_expect(fast_runtime != null and int(fast_runtime.marshal_phase) == 1, "fast descending ball should shorten Hwarang-followup Marshal wall jump")

	var slow_setup: Dictionary = _start_hwarang_followup_marshal_case({
		"ai_mode": "mythic league",
	}, {
		"ball_vel": Vector2(0.0, -8.0),
	})
	_advance_hwarang_followup_marshal_frames(slow_setup, 20)
	var slow_runtime: Object = slow_setup.get("runtime", null)
	_expect(slow_runtime != null and int(slow_runtime.marshal_phase) == 0, "slow upward ball should keep Hwarang-followup Marshal prep unshortened")
	_advance_hwarang_followup_marshal_frames(slow_setup, 5)
	_expect(int(slow_runtime.marshal_phase) == 1, "slow upward Hwarang-followup Marshal prep should finish on the original wall-jump timing")


func _test_core_flip_runtime() -> void:
	var runtime: Object = ViperSkillRuntime.new()
	var deps := _make_deps()
	var input: Object = deps["input_reader"]
	var dash_state: Object = deps["dash_state"]
	var skill_state: Object = deps["skill_state"]
	var audio: Object = deps["audio"]
	var orb: Object = deps["orb_hud_state"]
	var perk_state: Object = deps["runtime_perk_state"]
	var stage_background: Object = deps["stage_background"]
	var ai_state: Object = deps["ai_state"]
	var ball_effects: Object = deps["ball_effects"]
	var config := _base_config()
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 200.0

	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = false
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos + Vector2(120.0, 0.0), deps)
	runtime.register_player_ball_contact(deps, config)
	_expect(bool(runtime.get_snapshot().get("core_flip_ready", false)), "regular dash ball hit should open Hwarang Kick input window")

	input.snapshot["left_pressed"] = true
	input.snapshot["right_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(not bool(result.get("activated", false)), "A+D should buffer while the dash is still active")
	_expect(bool(runtime.get_snapshot().get("core_flip_ready", false)), "active dash should keep the Hwarang input window open")
	dash_state.snapshot["active"] = false
	dash_state.snapshot["recovering"] = true
	input.snapshot["left_pressed"] = false
	input.snapshot["right_pressed"] = false
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "buffered A+D should activate Hwarang Kick after dash motion ends")
	_expect(str(result.get("skill_name", "")) == "core_flip", "Hwarang activation should use the core_flip skill id")
	_expect(abs(float(result.get("special_gauge", 0.0)) - 80.0) < 0.01, "Hwarang Kick should spend 120 gauge")
	_expect(skill_state.triggered.back() == "core_flip", "Hwarang Kick should trigger its configured cooldown")
	_expect(audio.spin == 1, "Hwarang startup should play the blade spin sound")
	_expect(orb.spins == 1, "Hwarang activation should spin the skill orb gauge")
	_expect(dash_state.cancelled == 1, "Hwarang activation should consume the dash follow-up state")

	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))
	input.snapshot["left_pressed"] = false
	input.snapshot["right_pressed"] = false
	perk_state.levels["kick_enhance"] = 12
	var hit_result: Dictionary = {}
	var hit_frame := -1
	var marshal_ready_frame := -1
	for frame in range(180):
		config["special_gauge"] = gauge
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if result.has("ball_vel"):
			hit_result = result
			if hit_frame < 0:
				hit_frame = frame
			config["ball_vel"] = _get_vector2(result, "ball_vel", Vector2.ZERO)
		var snap: Dictionary = runtime.get_snapshot()
		if not bool(snap.get("core_flip_attack_active", false)) and bool(snap.get("marshal_ready", false)):
			marshal_ready_frame = frame
			break

	_expect(hit_result.has("ball_vel"), "Hwarang Kick should hit the live ball during the kick phase")
	_expect(hit_frame >= 0 and marshal_ready_frame >= 0 and marshal_ready_frame - hit_frame <= 12, "Hwarang-to-Marshal chain should re-arm quickly after the kick hit")
	_expect(_get_vector2(hit_result, "ball_vel", Vector2.ZERO).length() >= 17.5, "Hwarang Kick should use the marshal-grade 2.2x speed path")
	_expect(audio.hwarang == 1, "Hwarang ball hit should play the dedicated hwarangkick sound")
	_expect(perk_state.gold == 30, "Hwarang Kick hit should grant the marshal-grade 30 gold")
	_expect(stage_background.absorbed > 0, "Hwarang hit should route the impact cleanup hook")
	_expect(ball_effects.pulses == 1, "Hwarang Kick hit should register a visible ball hit pulse")
	_expect(ball_effects.last_kind == "viper_core_flip", "Hwarang Kick hit pulse should use its dedicated Viper core_flip kind")
	_expect(ball_effects.last_intensity >= 0.90, "Hwarang Kick hit pulse should be at least marshal-grade intensity")
	var final_snap: Dictionary = runtime.get_snapshot()
	var core_flip_particles: Array = final_snap.get("marshal_particles", []) as Array
	_expect(core_flip_particles.size() >= 18, "Hwarang Kick hit should leave marshal-grade local impact particles")
	_expect(int(final_snap.get("kick_skill_knockback_pending_pct", 0)) == 150, "kick_enhance Lv3+ should mark Hwarang's guarded knockback ball")
	_expect(int(final_snap.get("kick_guard_speed_reduction_pending_pct", 0)) == 50, "Hwarang hit should arm the boss-guard ball speed reduction like Marshal Kick (original temporary 2.2x boost, restored on boss return)")
	_expect(bool(final_snap.get("viper_knockback_overlay_active", false)), "guarded knockback ball should expose the Viper knockback overlay flag")
	var guard_result: Dictionary = runtime.consume_kick_skill_knockback(
		config["ball_pos"],
		config["boss_pos"],
		float(config["boss_paddle_width"]),
		config,
		deps
	)
	_expect(guard_result.has("boss_vel"), "guarded Hwarang knockback ball should apply a boss velocity on boss paddle guard")
	_expect(abs(ai_state.last_knockback_velocity) > 50.0, "guarded Hwarang knockback should use the original fire-style 150% force")
	_expect(abs(ai_state.last_knockback_frames - 18.0) < 0.01, "guarded Hwarang knockback should use the original 18-frame guard timer")
	_expect(audio.guard_knockback == 1, "guarded Hwarang knockback should play the nuckbackball cue")
	_expect(int(runtime.get_snapshot().get("kick_skill_knockback_pending_pct", -1)) == 0, "guarded Hwarang knockback should be consumed once")
	_expect(bool(final_snap.get("marshal_ready", false)), "Hwarang hit should open the Marshal Kick chain window")
	_expect(bool(final_snap.get("dark_blade_window", false)), "Hwarang hit should open the Dark Blade combo window when equipped")

	var backstep_before_marshal: int = audio.backstep
	input.snapshot["down_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	_expect(bool(result.get("activated", false)), "Hwarang follow-up input should activate Marshal Kick")
	_expect(str(result.get("skill_name", "")) == "marshal_kick", "Hwarang follow-up should spend the Marshal Kick skill, not Phantom Kick")
	_expect(audio.backstep == backstep_before_marshal + 1, "Hwarang follow-up Marshal startup should play one wall-climb cue")
	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))
	input.snapshot["down_pressed"] = false
	var marshal_hit_result: Dictionary = {}
	for _frame in range(140):
		config["special_gauge"] = 200.0
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if result.has("ball_vel") and marshal_hit_result.is_empty():
			marshal_hit_result = result
			config["ball_vel"] = _get_vector2(result, "ball_vel", Vector2.ZERO)
		if not bool(runtime.get_snapshot().get("marshal_active", false)) and not marshal_hit_result.is_empty():
			break
	_expect(marshal_hit_result.has("ball_vel"), "Hwarang follow-up Marshal should still hit the ball")
	var no_phantom_snap: Dictionary = runtime.get_snapshot()
	_expect(not bool(no_phantom_snap.get("marshal_first_hit_pending", false)), "Marshal after Hwarang should not arm Phantom delay when Phantom Kick is unavailable")
	_expect(not bool(no_phantom_snap.get("double_marshal_ready", false)), "Marshal after Hwarang should not open Phantom input when Phantom Kick is unavailable")
	_expect(not bool(no_phantom_snap.get("marshal_phantom_allowed", false)), "Unavailable Phantom Kick should clear the stale follow-up flag")
	var trigger_count_before_extra_input: int = skill_state.triggered.size()
	var backstep_before_extra_input: int = audio.backstep
	input.snapshot["down_pressed"] = true
	input.snapshot["action_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 200.0, config, deps)
	_expect(not bool(result.get("activated", false)), "Extra follow-up input should be ignored when Phantom Kick is unavailable")
	_expect(skill_state.triggered.size() == trigger_count_before_extra_input, "Ignored Phantom input should not trigger another skill cooldown")
	_expect(audio.backstep == backstep_before_extra_input, "Ignored Phantom input should not replay the wall-climb cue")


func _test_shadow_step_blocked_after_hwarang_chain() -> void:
	# Parity regression: after Hwarang(core_flip) -> Marshal Kick lands, a fresh S press must NOT
	# open Shadow Backstep. The frozen original gates shadow_step on an ACTIVE dash (_viper_in_dash)
	# plus _viper_shadow_step_chain_locked, and Hwarang ENDS the dash (rolling_active=False,
	# pingfighter.py:105368). The Godot port leaked the shadow_step dash ticket (dash_origin_valid /
	# dash_grace_frames) because core_flip activation never consumed it, so S after the chain wrongly
	# opened Shadow Backstep. Reverse-verified to FAIL when core_flip does not consume the dash ticket.
	var setup: Dictionary = _start_hwarang_followup_marshal_case()
	var runtime: Object = setup["runtime"]
	var deps: Dictionary = setup["deps"]
	var config: Dictionary = setup["config"]
	# Real Viper equips Shadow Backstep (a base skill) alongside Hwarang; the shared fixture omits it.
	deps["skill_config"].extra_equipped = ["shadow_step"]
	var input: Object = deps["input_reader"]
	# Advance until the Marshal Kick fully lands (chain complete, back on the ground).
	for _i in range(220):
		_advance_core_flip_frames(setup, 1)
		if not bool(runtime.get_snapshot().get("marshal_active", false)):
			break
	_expect(not bool(runtime.get_snapshot().get("marshal_active", false)), "Marshal Kick should land before the post-chain S test")
	_expect(not bool(runtime.get_snapshot().get("core_flip_attack_active", false)), "Hwarang should be done before the post-chain S test")
	var player_pos: Vector2 = _get_vector2(setup, "player_pos", Vector2.ZERO)
	# Fresh S edge after landing.
	input.snapshot["down_pressed"] = false
	input.snapshot["left_pressed"] = false
	input.snapshot["right_pressed"] = false
	input.snapshot["action_pressed"] = false
	runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 200.0, config, deps)  # settle the S release edge
	var hologram_before: bool = bool(runtime.get_snapshot().get("shadow_hologram_active", false))
	input.snapshot["down_pressed"] = true
	var s_result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 200.0, config, deps)
	_expect(str(s_result.get("skill_name", "")) != "shadow_step", "S after the Hwarang->Marshal chain must NOT fire Shadow Backstep (dash already spent on Hwarang)")
	_expect(bool(runtime.get_snapshot().get("shadow_hologram_active", false)) == hologram_before, "post-chain S must not newly open the Shadow Backstep hologram")


func _start_core_flip_prep_case(config_overrides: Dictionary = {}) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var deps := _make_deps()
	var input: Object = deps["input_reader"]
	var dash_state: Object = deps["dash_state"]
	var config := _base_config()
	_apply_config_overrides(config, config_overrides)
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 200.0
	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = false
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos + Vector2(120.0, 0.0), deps)
	runtime.register_player_ball_contact(deps, config)
	dash_state.snapshot["active"] = false
	dash_state.snapshot["recovering"] = true
	input.snapshot["left_pressed"] = true
	input.snapshot["right_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	input.snapshot["left_pressed"] = false
	input.snapshot["right_pressed"] = false
	_expect(bool(result.get("activated", false)), "Hwarang dynamic prep retime setup should activate Hwarang Kick")
	return {
		"runtime": runtime,
		"deps": deps,
		"config": config,
		"player_pos": _get_vector2(result, "player_pos", player_pos),
		"gauge": float(result.get("special_gauge", gauge)),
	}


func _advance_core_flip_frames(setup: Dictionary, frames: int) -> void:
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = setup.get("config", {})
	var player_pos: Vector2 = _get_vector2(setup, "player_pos", Vector2.ZERO)
	var gauge: float = float(setup.get("gauge", 0.0))
	_expect(runtime != null, "Hwarang dynamic prep retime setup should include runtime")
	for _i in range(frames):
		var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
	setup["player_pos"] = player_pos
	setup["gauge"] = gauge


func _start_hwarang_followup_marshal_case(config_overrides: Dictionary = {}, followup_overrides: Dictionary = {}) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var deps := _make_deps()
	var input: Object = deps["input_reader"]
	var dash_state: Object = deps["dash_state"]
	var config := _base_config()
	_apply_config_overrides(config, config_overrides)
	var player_pos := Vector2(302.5, 680.0)
	var gauge := 200.0
	dash_state.snapshot["active"] = true
	dash_state.snapshot["is_half"] = false
	runtime.observe_after_movement(1.0 / 60.0, player_pos, player_pos + Vector2(120.0, 0.0), deps)
	runtime.register_player_ball_contact(deps, config)
	dash_state.snapshot["active"] = false
	dash_state.snapshot["recovering"] = true
	input.snapshot["left_pressed"] = true
	input.snapshot["right_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	input.snapshot["left_pressed"] = false
	input.snapshot["right_pressed"] = false
	_expect(bool(result.get("activated", false)), "Hwarang-followup Marshal retime setup should activate Hwarang Kick")
	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))

	for _frame in range(220):
		config["special_gauge"] = gauge
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
		if result.has("ball_vel"):
			config["ball_vel"] = _get_vector2(result, "ball_vel", Vector2.ZERO)
		runtime.update_effects(1.0, Time.get_ticks_msec(), config, deps)
		if bool(runtime.get_snapshot().get("marshal_ready", false)):
			break

	_expect(bool(runtime.get_snapshot().get("marshal_ready", false)), "Hwarang Kick hit should open the Marshal follow-up window")
	_expect(runtime.marshal_ready_from_core_flip_chain, "Marshal follow-up window should remember it came from Hwarang Kick")
	_apply_config_overrides(config, followup_overrides)
	input.snapshot["down_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
	input.snapshot["down_pressed"] = false
	_expect(bool(result.get("activated", false)), "Hwarang follow-up input should activate Marshal Kick")
	_expect(str(result.get("skill_name", "")) == "marshal_kick", "Hwarang follow-up should start Marshal Kick")
	_expect(runtime.marshal_from_core_flip_chain, "Active Marshal Kick should remember the Hwarang chain source")
	return {
		"runtime": runtime,
		"deps": deps,
		"config": config,
		"player_pos": _get_vector2(result, "player_pos", player_pos),
		"gauge": float(result.get("special_gauge", gauge)),
	}


func _advance_hwarang_followup_marshal_frames(setup: Dictionary, frames: int) -> void:
	var runtime: Object = setup.get("runtime", null)
	var deps: Dictionary = setup.get("deps", {})
	var config: Dictionary = setup.get("config", {})
	var player_pos: Vector2 = _get_vector2(setup, "player_pos", Vector2.ZERO)
	var gauge: float = float(setup.get("gauge", 0.0))
	_expect(runtime != null, "Hwarang-followup Marshal retime setup should include runtime")
	for _i in range(frames):
		var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, deps)
		player_pos = _get_vector2(result, "player_pos", player_pos)
		gauge = float(result.get("special_gauge", gauge))
	setup["player_pos"] = player_pos
	setup["gauge"] = gauge


func _apply_config_overrides(config: Dictionary, overrides: Dictionary) -> void:
	for key in overrides.keys():
		config[key] = overrides[key]


func _make_deps() -> Dictionary:
	return {
		"input_reader": FakeInput.new(),
		"dash_state": FakeDashState.new(),
		"skill_config": FakeSkillConfig.new(),
		"skill_state": FakeSkillState.new(),
		"audio": FakeAudio.new(),
		"feedback": FakeFeedback.new(),
		"orb_hud_state": FakeOrbHud.new(),
		"runtime_perk_state": FakePerkState.new(),
		"stage_background": FakeStageBackground.new(),
		"ai_state": FakeAiState.new(),
		"ball_effects": FakeBallEffects.new(),
	}


func _base_config() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 680.0,
		"ball_size": 28.6,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(620.0, 350.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_impact_boost": 1.0,
		"special_gauge": 200.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
