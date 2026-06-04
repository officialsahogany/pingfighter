extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := true

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


func _init() -> void:
	_verify_permanent_and_rental_weapon_model()
	_verify_late_firearm_python_ammo_counts()
	_verify_firearm_runtime_consumes_after_readiness()
	_verify_serve_wait_input_does_not_fire_firearms()
	_verify_commando_pistol_instant_fire_keeps_horizontal_input()
	_verify_ak47_hold_fire_slows_horizontal_movement()
	_verify_supply_drop_grants_one_rental_weapon()
	_verify_stage_boundary_weapon_policy()
	_verify_player_controller_stage_boundary_integration()

	if _failures.is_empty():
		print("commando_weapon_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_permanent_and_rental_weapon_model() -> void:
	var config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()

	_expect(config.unlock_and_equip_skill("net_gun"), "net gun should equip into shared firearm slots")
	_expect(config.unlock_and_equip_skill("bazooka"), "bazooka should equip into shared firearm slots")
	_expect(config.unlock_and_equip_skill("commando_pistol"), "Commando pistol should equip into shared firearm slots")
	_expect(not config.unlock_and_equip_skill("ak47"), "shared slots should cap permanent firearms at three")
	controller.sync_equipped_permanent(config)

	var weapons: Array = controller.get_weapons()
	_expect(weapons == ["pistol", "net_gun", "bazooka", "commando_pistol"], "weapon list should be one derived list, not stacked HUD entries")
	_expect(str(controller.cycle_weapon(1, 1000)) == "net_gun", "wheel down should advance to first permanent firearm")
	var net_weapon := controller.get_current_weapon_data()
	_expect(int(net_weapon.get("ammo_current", -1)) == 3, "net gun should expose Python 3-harpoon ammo")
	_expect(int(net_weapon.get("ammo_max", -1)) == 3, "net gun max ammo should stay at three")
	_expect(str(controller.cycle_weapon(1, 1010)) == "net_gun", "switch debounce should ignore immediate repeat")
	_expect(str(controller.cycle_weapon(1, 1200)) == "bazooka", "wheel down should advance after debounce")

	_expect(controller.add_rental_weapon("ak47", 1, 1), "rental AK-47 should be accepted when not permanent-owned")
	_expect(controller.get_weapons().has("ak47"), "rental weapon should appear in the same selector list")
	_expect(controller.set_current_weapon("ak47"), "rental weapon should become selectable")
	_expect(controller.consume_current_weapon_ammo(), "rental ammo should be consumable")
	_expect(not controller.get_weapons().has("ak47"), "depleted rental weapon should be released")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "current weapon should fall back when selected rental is released")

	_expect(controller.add_rental_weapon("fire_support", 1, 2), "stage rental should be accepted")
	_expect(controller.set_current_weapon("fire_support"), "fire support rental should be selectable for two-use ammo smoke")
	_expect(controller.consume_current_weapon_ammo(), "first fire support call should consume one radio")
	var half_spent_fire_support: Dictionary = controller.get_current_weapon_data()
	_expect(int(half_spent_fire_support.get("ammo_current", -1)) == 1, "fire support should keep one radio after the first call")
	_expect(bool(half_spent_fire_support.get("can_fire", false)), "fire support should remain usable after the first call")
	var removed: Array = controller.remove_stage_rentals(2)
	_expect(removed.has("fire_support"), "stage transition should clear older rentals")


func _verify_late_firearm_python_ammo_counts() -> void:
	var fire_support_config := CommandoSkillConfig.new()
	var fire_support_controller := CommandoWeaponController.new()
	_expect(fire_support_config.unlock_and_equip_skill("fire_support"), "fire support should unlock for two-call ammo count smoke")
	fire_support_controller.sync_equipped_permanent(fire_support_config)
	_expect(fire_support_controller.set_current_weapon("fire_support"), "fire support should be selectable for two-call ammo count smoke")
	var fire_support_weapon: Dictionary = fire_support_controller.get_current_weapon_data()
	_expect(int(fire_support_weapon.get("ammo_current", -1)) == 2, "fire support should expose two radio calls")
	_expect(int(fire_support_weapon.get("ammo_max", -1)) == 2, "fire support max ammo should stay at two")
	_expect(fire_support_controller.consume_current_weapon_ammo(), "first permanent fire support call should consume one radio")
	var once_spent_fire_support: Dictionary = fire_support_controller.get_current_weapon_data()
	_expect(int(once_spent_fire_support.get("ammo_current", -1)) == 1, "first fire support use should leave one radio")
	_expect(bool(once_spent_fire_support.get("can_fire", false)), "fire support should stay fire-capable with one radio left")
	_expect(fire_support_controller.consume_current_weapon_ammo(), "second permanent fire support call should consume the final radio")
	var depleted_fire_support: Dictionary = fire_support_controller.get_current_weapon_data()
	_expect(int(depleted_fire_support.get("ammo_current", -1)) == 0, "second fire support use should leave zero radios")
	_expect(not bool(depleted_fire_support.get("can_fire", true)), "fire support should stop firing after both radios are spent")

	var bowling_config := CommandoSkillConfig.new()
	var bowling_controller := CommandoWeaponController.new()
	_expect(bowling_config.unlock_and_equip_skill("bowling_trap"), "bowling trap should unlock for Python ammo count smoke")
	bowling_controller.sync_equipped_permanent(bowling_config)
	_expect(bowling_controller.set_current_weapon("bowling_trap"), "bowling trap should be selectable for Python ammo count smoke")
	var bowling_weapon: Dictionary = bowling_controller.get_current_weapon_data()
	_expect(int(bowling_weapon.get("ammo_current", -1)) == 3, "bowling trap should expose the Python 3-trap ammo count")
	_expect(int(bowling_weapon.get("ammo_max", -1)) == 3, "bowling trap max ammo should stay at three")

	var drone_config := CommandoSkillConfig.new()
	var drone_controller := CommandoWeaponController.new()
	_expect(drone_config.unlock_and_equip_skill("suicide_drone"), "suicide drone should unlock for Python ammo count smoke")
	drone_controller.sync_equipped_permanent(drone_config)
	_expect(drone_controller.set_current_weapon("suicide_drone"), "suicide drone should be selectable for Python ammo count smoke")
	var drone_weapon: Dictionary = drone_controller.get_current_weapon_data()
	_expect(int(drone_weapon.get("ammo_current", -1)) == 4, "suicide drone should expose the Python 4-drone ammo count")
	_expect(int(drone_weapon.get("ammo_max", -1)) == 4, "suicide drone max ammo should stay at four")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var spanish_ak47_text: String = fire_support_controller._get_ak47_ammo_text({"ammo_current": 2, "ammo_max": 4, "duration_frames": 90.0})
	_expect(spanish_ak47_text.find("2/4") >= 0 and spanish_ak47_text.find("Durabilidad 1.5s") >= 0, "AK-47 ammo text should localize durability to Spanish")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var portuguese_ak47_text: String = fire_support_controller._get_ak47_ammo_text({"ammo_current": 2, "ammo_max": 4, "duration_frames": 90.0})
	_expect(portuguese_ak47_text.find("2/4") >= 0 and portuguese_ak47_text.find("Durabilidade 1.5s") >= 0, "AK-47 ammo text should localize durability to Brazilian Portuguese")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	var russian_ak47_text: String = fire_support_controller._get_ak47_ammo_text({"ammo_current": 2, "ammo_max": 4, "duration_frames": 90.0})
	_expect(russian_ak47_text.find("2/4") >= 0 and russian_ak47_text.find("Прочность 1.5с") >= 0, "AK-47 ammo text should localize durability to Russian")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_stage_boundary_weapon_policy() -> void:
	var controller := CommandoWeaponController.new()
	_expect(controller.unlock_permanent_weapon("bazooka"), "bazooka should unlock for stage boundary policy")
	_expect(controller.set_current_weapon("bazooka"), "bazooka should be selectable for stage boundary policy")
	_spend_current_weapon_ammo(controller, 4, "bazooka should spend all ammo before round reset")
	_expect(controller.add_rental_weapon("ak47", 1, 4), "same-stage rental should be available before round reset")

	var round_result: Dictionary = controller.reset_round()
	_expect(bool(round_result.get("round_reset", false)), "round reset should be explicit for Commando weapons")
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "round reset should not refill permanent firearms")
	_expect(controller.get_weapons().has("ak47"), "round reset should preserve rental firearms")

	var stage_one_result: Dictionary = controller.prepare_stage_start(1)
	_expect(bool(stage_one_result.get("stage_start", false)), "first stage-start preparation should run once")
	_expect(_get_array(stage_one_result.get("refilled_permanent", [])).is_empty(), "stage start should not report free permanent firearm refills")
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "stage start should preserve spent permanent firearm ammo")
	_expect(controller.get_weapons().has("ak47"), "same-stage rental should survive stage-start preparation")

	_expect(controller.refill_weapon_to_max("bazooka"), "explicit Commando reload should still refill permanent firearms")
	_spend_current_weapon_ammo(controller, 4, "bazooka should spend all ammo again after explicit reload")
	var same_stage_result: Dictionary = controller.prepare_stage_start(1)
	_expect(not bool(same_stage_result.get("stage_start", true)), "same stage should not keep refilling permanent firearms")
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "same-stage preparation should leave spent permanent ammo alone")

	var next_stage_result: Dictionary = controller.prepare_stage_start(2)
	_expect(bool(next_stage_result.get("stage_start", false)), "next stage preparation should run on stage change")
	_expect(_get_array(next_stage_result.get("removed_rentals", [])).has("ak47"), "next stage should report removed rentals")
	_expect(not controller.get_weapons().has("ak47"), "next stage should clear older rentals")
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "next stage should preserve spent permanent firearm ammo")

	var base_controller := CommandoWeaponController.new()
	_spend_current_weapon_ammo(base_controller, 3, "base pistol should spend ammo before stage transition")
	_expect(base_controller.start_current_weapon_reload(), "base pistol should enter reload before stage transition")
	var base_stage_result: Dictionary = base_controller.prepare_stage_start(2)
	var base_weapon: Dictionary = base_controller.get_current_weapon_data()
	_expect(_get_array(base_stage_result.get("refilled_permanent", [])).is_empty(), "stage transition should not report a base pistol refill")
	_expect(bool(base_stage_result.get("refilled_base_weapon", false)), "stage transition should report the base pistol refill separately")
	_expect(int(base_weapon.get("ammo_current", -1)) == 5, "stage transition should refill only the base pistol ammo")
	_expect(not bool(base_weapon.get("reloading", true)), "stage transition should finish the base pistol refill state")


func _verify_firearm_runtime_consumes_after_readiness() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	_expect(config.unlock_and_equip_skill("bazooka"), "bazooka should unlock for runtime fire test")
	controller.sync_equipped_permanent(config)
	_expect(controller.set_current_weapon("bazooka"), "bazooka should be selectable")

	var deps := {
		"commando_weapon_controller": controller,
		"skill_state": state,
		"skill_config": config,
	}
	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, {}, deps)
	_expect(bool(result.get("fired", false)), "first ready bazooka shot should fire")
	_expect(int(controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "bazooka should spend one of four rockets")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "bazooka should remain fire-capable while rockets remain")
	_expect(state.get_cooldown_remaining("bazooka", Time.get_ticks_msec(), config.get_cooldown_seconds("bazooka")) > 0.0, "bazooka should start orb cooldown")

	_expect(controller.refill_current_permanent(), "permanent bazooka should refill through current permanent reload")
	runtime.reset()
	var blocked: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, {}, deps)
	_expect(bool(blocked.get("fire_failed", false)), "cooldown should block a refilled weapon before ammo is spent")
	_expect(bool(controller.get_current_weapon_data().get("can_fire", false)), "cooldown block should leave refilled ammo intact")
	_expect(runtime.update_input({"action_pressed": true, "down_pressed": true}, 500.0, {}, deps).is_empty(), "supply-drop hold input should not also fire")


func _verify_serve_wait_input_does_not_fire_firearms() -> void:
	var pistol_controller := CommandoWeaponController.new()
	var pistol_runtime := CommandoFirearmRuntime.new()
	var pistol_round := FakeRoundState.new()
	var pistol_deps := {
		"commando_weapon_controller": pistol_controller,
		"round_state": pistol_round,
	}
	var serve_press: Dictionary = pistol_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		pistol_deps
	)
	_expect(serve_press.is_empty(), "serve-wait launch input should not queue the base pistol")
	_expect(int(pistol_controller.get_current_weapon_data().get("ammo_current", -1)) == 5, "serve-wait base pistol input should not spend ammo")
	pistol_round.waiting_for_serve = false
	var held_after_serve: Dictionary = pistol_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": false},
		500.0,
		{},
		pistol_deps
	)
	_expect(held_after_serve.is_empty(), "held serve input should stay suppressed after launch until release")
	_expect(int(pistol_controller.get_current_weapon_data().get("ammo_current", -1)) == 5, "held serve input should still preserve base pistol ammo")
	pistol_runtime.update_input({"action_pressed": false, "action_just_released": true}, 500.0, {}, pistol_deps)
	var fresh_pistol_press: Dictionary = pistol_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		pistol_deps
	)
	_expect(bool(fresh_pistol_press.get("shot_queued", false)), "fresh post-serve press should still queue the base pistol")

	var ak_config := CommandoSkillConfig.new()
	var ak_state := CommandoSkillState.new()
	var ak_controller := CommandoWeaponController.new()
	var ak_runtime := CommandoFirearmRuntime.new()
	var ak_round := FakeRoundState.new()
	_expect(ak_config.unlock_and_equip_skill("ak47"), "AK-47 should unlock for serve-wait suppression smoke")
	ak_controller.sync_equipped_permanent(ak_config)
	_expect(ak_controller.set_current_weapon("ak47"), "AK-47 should be selected for serve-wait suppression smoke")
	var ak_deps := {
		"commando_weapon_controller": ak_controller,
		"skill_state": ak_state,
		"skill_config": ak_config,
		"round_state": ak_round,
	}
	var ak_serve_press: Dictionary = ak_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		ak_deps
	)
	_expect(ak_serve_press.is_empty(), "serve-wait launch input should not fire AK-47")
	_expect(int(ak_controller.get_current_weapon_data().get("ammo_current", -1)) == 90, "serve-wait AK-47 input should not spend ammo")
	ak_round.waiting_for_serve = false
	var ak_held_after_serve: Dictionary = ak_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": false},
		500.0,
		{},
		ak_deps
	)
	_expect(ak_held_after_serve.is_empty(), "held serve input should not start AK-47 auto-fire after launch")
	_expect(int(ak_controller.get_current_weapon_data().get("ammo_current", -1)) == 90, "held serve input should preserve AK-47 ammo")
	_expect(is_equal_approx(float(ak_runtime.get_movement_speed_multiplier()), 1.0), "held serve input should not leave AK-47 slowdown active")
	ak_runtime.update_input({"action_pressed": false, "action_just_released": true}, 500.0, {}, ak_deps)
	var fresh_ak_press: Dictionary = ak_runtime.update_input(
		{"action_pressed": true, "action_just_pressed": true},
		500.0,
		{},
		ak_deps
	)
	_expect(bool(fresh_ak_press.get("fired", false)), "fresh post-serve press should still fire AK-47")
	_expect(int(ak_controller.get_current_weapon_data().get("ammo_current", -1)) == 89, "fresh AK-47 press should spend exactly one bullet")


func _verify_commando_pistol_instant_fire_keeps_horizontal_input() -> void:
	var player := CommandoPlayerController.new()
	var config := CommandoSkillConfig.new()
	var skill_state := CommandoSkillState.new()
	var weapon_controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var input_reader := FakeInputReader.new()
	_expect(config.unlock_and_equip_skill("commando_pistol"), "Commando pistol should unlock for instant-fire movement smoke")
	weapon_controller.sync_equipped_permanent(config)
	_expect(weapon_controller.set_current_weapon("commando_pistol"), "Commando pistol should be selected for instant-fire movement smoke")
	input_reader.snapshot = {
		"action_pressed": true,
		"right_pressed": true,
		"direction": 1.0,
	}

	var deps := {
		"input_reader": input_reader,
		"skill_config": config,
		"skill_state": skill_state,
		"commando_weapon_controller": weapon_controller,
		"commando_firearm_runtime": runtime,
		"movement_state": PlayerMovementState.new(),
	}
	var result: Dictionary = player.update(
		1.0 / 60.0,
		0,
		Vector2(100.0, 650.0),
		0.0,
		{
			"special_gauge": 500.0,
			"current_stage": 1,
			"paddle_width": 88.0,
			"paddle_height": 40.0,
			"play_left": 0.0,
			"play_right": 760.0,
		},
		deps
	)
	var moved_pos: Vector2 = _get_vector2(result.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	_expect(moved_pos.x > 100.0, "Commando pistol instant fire should not lock horizontal movement on the shot frame")
	_expect(float(result.get("player_speed", 0.0)) > 0.0, "Commando pistol instant fire should keep normal movement speed")
	_expect(not bool(runtime.is_player_control_locked()), "Commando pistol runtime should not expose a ready-motion control lock")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 11, "instant-fire shot should still spend one pistol bullet")


func _verify_ak47_hold_fire_slows_horizontal_movement() -> void:
	var player := CommandoPlayerController.new()
	var config := CommandoSkillConfig.new()
	var skill_state := CommandoSkillState.new()
	var weapon_controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var input_reader := FakeInputReader.new()
	_expect(config.unlock_and_equip_skill("ak47"), "AK-47 should unlock for movement debuff smoke")
	weapon_controller.sync_equipped_permanent(config)
	_expect(weapon_controller.set_current_weapon("ak47"), "AK-47 should be selected for movement debuff smoke")
	input_reader.snapshot = {
		"action_pressed": true,
		"action_just_pressed": true,
		"right_pressed": true,
		"direction": 1.0,
	}

	var deps := {
		"input_reader": input_reader,
		"skill_config": config,
		"skill_state": skill_state,
		"commando_weapon_controller": weapon_controller,
		"commando_firearm_runtime": runtime,
		"movement_state": PlayerMovementState.new(),
	}
	var result: Dictionary = player.update(
		1.0 / 60.0,
		0,
		Vector2(100.0, 650.0),
		6.0,
		{
			"special_gauge": 500.0,
			"current_stage": 1,
			"paddle_width": 88.0,
			"paddle_height": 40.0,
			"play_left": 0.0,
			"play_right": 760.0,
		},
		deps
	)
	var moved_pos: Vector2 = _get_vector2(result.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	_expect(is_equal_approx(float(result.get("player_speed", -1.0)), 3.0), "AK-47 held fire should clamp player speed to 50% of the normal max")
	_expect(is_equal_approx(moved_pos.x, 103.0), "AK-47 held fire should still allow slowed horizontal movement")
	_expect(is_equal_approx(float(runtime.get_movement_speed_multiplier()), 0.5), "AK-47 runtime should expose active movement slowdown to the player controller")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 89, "AK-47 movement debuff shot should spend one bullet")


func _verify_supply_drop_grants_one_rental_weapon() -> void:
	var config := CommandoSkillConfig.new()
	var state := CommandoSkillState.new()
	var controller := CommandoWeaponController.new()
	var supply := CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": controller,
		"commando_supply_drop_forced_payloads": [
			{"type": "rental_weapon", "weapon_id": "net_gun"},
		],
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
		"current_stage": 1,
	}

	var activate_result: Dictionary = supply.update_input({"down_pressed": true, "action_pressed": false}, 1.0, 500.0, config, state, deps)
	_expect(bool(activate_result.get("activated", false)), "holding down should activate supply drop without action input")
	var resolve_result: Dictionary = supply.update(4.2, deps)
	_expect(bool(resolve_result.get("drop_resolved", false)), "supply drop should resolve after delay")
	_expect(controller.get_weapons().size() == 1, "resolved supply should wait for direct pickup before granting a rental")
	var collectible: Dictionary = _get_first_collectible(supply)
	var pickup_pos: Vector2 = collectible.get("pos", collectible.get("drop_position", Vector2.ZERO))
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var pickup_result: Dictionary = supply.update(0.01, deps)
	_expect(bool(pickup_result.get("pickup_resolved", false)), "supply rental should be granted when the player picks up the box")
	_expect(controller.get_weapons().size() == 2, "picked supply should add exactly one selectable rental weapon beside the base pistol")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "picked supply rental should immediately switch the firearm HUD to the granted weapon")
	var highlight_state: Dictionary = controller.get_hud_highlight_state()
	_expect(bool(highlight_state.get("active", false)), "picked supply rental should trigger the firearm HUD highlight")
	_expect(str(highlight_state.get("weapon_id", "")) == "net_gun", "firearm HUD highlight should be tied to the granted rental weapon")
	controller.update_timers(30.0)
	var ticking_highlight: Dictionary = controller.get_hud_highlight_state()
	_expect(float(ticking_highlight.get("timer_frames", 0.0)) < float(highlight_state.get("timer_frames", 0.0)), "firearm HUD highlight should tick through the weapon controller timer path")
	controller.update_timers(200.0)
	_expect(not bool(controller.get_hud_highlight_state().get("active", true)), "firearm HUD highlight should expire after its original-style timer")


func _verify_player_controller_stage_boundary_integration() -> void:
	var player := CommandoPlayerController.new()
	var config := CommandoSkillConfig.new()
	var controller := CommandoWeaponController.new()
	_expect(config.unlock_and_equip_skill("bazooka"), "bazooka should equip for player controller stage policy")
	controller.sync_equipped_permanent(config)
	_expect(controller.set_current_weapon("bazooka"), "bazooka should be selected for player controller stage policy")
	_spend_current_weapon_ammo(controller, 4, "bazooka should spend all ammo before controller stage update")
	_expect(controller.add_rental_weapon("ak47", 1, 5), "stage-one rental should exist before controller stage update")

	var deps := {
		"input_reader": FakeInputReader.new(),
		"skill_config": config,
		"commando_weapon_controller": controller,
	}
	_update_player_for_stage(player, deps, 1)
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "Commando player update should prepare the current stage without free firearm ammo")
	_expect(controller.get_weapons().has("ak47"), "Commando player update should keep same-stage rentals")

	_expect(controller.refill_weapon_to_max("bazooka"), "explicit reload should still refill after player-driven stage preparation")
	_spend_current_weapon_ammo(controller, 4, "bazooka should spend all ammo after explicit reload")
	_update_player_for_stage(player, deps, 1)
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "Commando player update should not refill repeatedly inside the same stage")

	_update_player_for_stage(player, deps, 2)
	_expect(not bool(controller.get_weapon_data("bazooka").get("can_fire", true)), "Commando player update should preserve spent ammo when the stage changes")
	_expect(not controller.get_weapons().has("ak47"), "Commando player update should clear older rentals on stage change")


func _update_player_for_stage(player: Object, deps: Dictionary, stage_id: int) -> void:
	player.update(
		0.01,
		0,
		Vector2(100.0, 700.0),
		0.0,
		{
			"special_gauge": 500.0,
			"current_stage": stage_id,
			"paddle_width": 88.0,
			"paddle_height": 40.0,
			"play_left": 0.0,
			"play_right": 760.0,
		},
		deps
	)


func _spend_current_weapon_ammo(controller: Object, amount: int, message: String) -> void:
	for _i in range(amount):
		_expect(bool(controller.consume_current_weapon_ammo()), message)


func _get_first_collectible(supply: Object) -> Dictionary:
	var drops: Array = supply.get_snapshot().get("collectible_drops", [])
	if drops.is_empty() or not (drops[0] is Dictionary):
		return {}
	return drops[0]


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
