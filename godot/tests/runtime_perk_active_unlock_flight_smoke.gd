extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const RuntimePerkActiveUnlockFlight := preload("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
const RuntimePerkStarpointAbsorption := preload("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var special_gauge := 0.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false


class FakeGameAudio:
	extends RefCounted

	var item_get_calls := 0
	var weapon_change_calls := 0

	func play_item_get() -> void:
		item_get_calls += 1

	func play_commando_weapon_change() -> void:
		weapon_change_calls += 1


class FakeActiveItemRuntime:
	extends RefCounted

	var dimension_gate_calls := 0

	func activate_dimension_gate(_registry: Object = null) -> bool:
		dimension_gate_calls += 1
		return true


class FakeRuntimePerkCatalog:
	extends RefCounted

	var choices: Array = []

	func get_choices(
		_character_type: String,
		_levels: Dictionary,
		_exclude_instant: bool,
		_target_count: int,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return choices.duplicate(true)


class FakeSkillConfig:
	extends RefCounted

	var equipped_skills: Array = ["drive", "power_smashing"]
	var unlock_calls := 0
	var reset_cooldown_calls := 0
	var runtime_cooldown_multiplier := 1.0

	func get_snapshot() -> Dictionary:
		return {
			"max_slots": 5,
			"equipped_skills": equipped_skills.duplicate(),
		}

	func unlock_and_equip_skill(skill_name: String) -> bool:
		unlock_calls += 1
		if equipped_skills.has(skill_name):
			return true
		if equipped_skills.size() >= 5:
			return false
		equipped_skills.append(skill_name)
		return true

	func set_runtime_cooldown_multiplier(multiplier: float) -> void:
		runtime_cooldown_multiplier = multiplier

	func reset_cooldowns() -> void:
		reset_cooldown_calls += 1


class FakeDashState:
	extends RefCounted

	var refill_calls := 0

	func refill_tokens() -> void:
		refill_calls += 1


class FakeCommandoWeaponController:
	extends RefCounted

	var sync_calls := 0
	var last_skill_config: Object = null
	var highlight_calls := 0
	var last_highlight_skill := ""

	func sync_equipped_permanent(skill_config: Object) -> void:
		sync_calls += 1
		last_skill_config = skill_config

	func trigger_hud_highlight(skill_name: String) -> void:
		highlight_calls += 1
		last_highlight_skill = skill_name


class FakeStarpointStage:
	extends RefCounted

	var starpoint_drops: Array = [{"pos": Vector2(1.0, 2.0)}]
	var starpoint_particles: Array = [{"pos": Vector2(3.0, 4.0)}]


class FakeFlightState:
	extends RefCounted

	var choice_flight_effect: Dictionary = {}


class FakeRegistry:
	extends RefCounted

	var runtime_perk_catalog := FakeRuntimePerkCatalog.new()
	var skill_config := FakeSkillConfig.new()
	var commando_skill_config := FakeSkillConfig.new()
	var commando_weapon_controller := FakeCommandoWeaponController.new()
	var smasher_dash_state := FakeDashState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var battle_view_layout := BattleViewLayout.new()
	var battle_scene_config := BattleSceneConfig.new()
	var game_audio := FakeGameAudio.new()
	var stage1_balloon_event := FakeStarpointStage.new()
	var stage2_pillar_background := FakeStarpointStage.new()
	var stage3_boss_skill_state := FakeStarpointStage.new()
	var stage4_bird_event := FakeStarpointStage.new()
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"runtime_perk_catalog":
				return runtime_perk_catalog
			"smasher_skill_config":
				return skill_config
			"smasher_skill_state":
				return skill_config
			"smasher_dash_state":
				return smasher_dash_state
			"commando_skill_config":
				return commando_skill_config
			"commando_weapon_controller":
				return commando_weapon_controller
			"active_item_runtime":
				return active_item_runtime
			"battle_view_layout":
				return battle_view_layout
			"battle_scene_config":
				return battle_scene_config
			"game_audio":
				return game_audio
			"stage1_balloon_event":
				return stage1_balloon_event
			"stage2_pillar_background":
				return stage2_pillar_background
			"stage3_boss_skill_state":
				return stage3_boss_skill_state
			"stage4_bird_event":
				return stage4_bird_event
		return null

	func has_requested_key(key: String) -> bool:
		return requested_keys.has(key)


func _init() -> void:
	_verify_active_unlock_flight_state_application_helper()
	_verify_active_unlock_flight_selected_card_builder()
	_verify_active_unlock_flight_advance_helper()
	_verify_active_unlock_waits_for_orb_flight()
	_verify_active_unlock_chain_reopens_with_input_guard()
	_verify_soldier_unlock_syncs_commando_controller()
	_verify_result_box_dimension_gate_waits_for_next_spawn_intro_finish()
	_verify_result_box_full_gauge_waits_for_next_spawn_intro_finish()
	_verify_starpoint_collection_update_helper()
	_verify_collect_starpoints_preserves_in_flight_drops()
	_verify_starpoint_absorption_tracks_player_after_choice()
	print("runtime_perk_active_unlock_flight_smoke: ok")
	quit(0)


func _verify_active_unlock_flight_state_application_helper() -> void:
	var helper := RuntimePerkActiveUnlockFlight.new()
	var state := FakeFlightState.new()
	var effect := {
		"active": true,
		"choice": {"id": "unlock_plasma", "unlocks_skill": "plasma"},
		"choice_id": "unlock_plasma",
		"skill_id": "plasma",
		"age": 0.0,
	}
	var apply_result: Dictionary = helper.apply_effect_state_update(state, effect)
	_expect(bool(apply_result.get("accepted", false)), "active unlock flight helper should apply flight state")
	_expect(helper.is_active(state.choice_flight_effect), "active unlock flight helper should store an active flight")
	_expect(helper.is_active_from_runtime_state(state), "active unlock flight helper should read active flight state from runtime-state facade")
	_expect(str(state.choice_flight_effect.get("skill_id", "")) == "plasma", "active unlock flight helper should keep skill id")
	effect["skill_id"] = "mutated_after_apply"
	_expect(str(state.choice_flight_effect.get("skill_id", "")) == "plasma", "active unlock flight helper should deep-copy payloads")
	_expect(not helper.is_active_from_runtime_state(null), "active unlock flight runtime-state facade should reject missing state")
	_expect(not bool(helper.apply_effect_state_update(null, effect).get("accepted", true)), "active unlock flight helper should reject null state")
	var consumed: Dictionary = helper.consume_effect(state.choice_flight_effect)
	_expect(str(consumed.get("skill_id", "")) == "plasma", "active unlock flight helper should consume a flight snapshot")
	consumed["skill_id"] = "mutated_after_consume"
	_expect(state.choice_flight_effect.is_empty(), "active unlock flight helper should clear consumed flight state")
	_expect(not helper.is_active_from_runtime_state(state), "active unlock flight runtime-state facade should report consumed state as inactive")
	_expect(helper.consume_effect(state.choice_flight_effect).is_empty(), "active unlock flight helper should tolerate empty consume calls")
	var landing_payload: Dictionary = helper.build_landing_payload(consumed)
	_expect(bool(landing_payload.get("accepted", false)), "active unlock flight helper should build landing payloads from consumed effects")
	_expect(str(landing_payload.get("choice_id", "")) == "unlock_plasma", "active unlock flight helper should preserve landing choice id")
	var landing_choice: Dictionary = _get_dict(landing_payload.get("choice", {}))
	_expect(str(landing_choice.get("id", "")) == "unlock_plasma", "active unlock flight helper should preserve landing choice data")
	landing_choice["id"] = "mutated_after_landing_payload"
	_expect(str(_get_dict(consumed.get("choice", {})).get("id", "")) == "unlock_plasma", "active unlock flight landing payload should deep-copy choice data")
	_expect(not bool(helper.build_landing_payload({}).get("accepted", true)), "active unlock flight helper should reject empty landing effects")
	_expect(not bool(helper.build_landing_payload({"choice_id": "missing_choice"}).get("accepted", true)), "active unlock flight helper should reject landing effects without choice data")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
	var confirm_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var active_body: String = _function_body(state_source, "func is_choice_flight_active(")
	var finish_body: String = _function_body(confirm_flow_source, "func finish_choice_flight_effect(")
	var update_body: String = _function_body(state_source, "func _update_choice_flight_effect(")
	_expect(state_source.find("_choice_confirm_flow.choose_selected") >= 0, "runtime perk state should route selection confirm through confirm-flow")
	_expect(helper_source.find("func is_active_from_runtime_state(") >= 0, "active unlock flight helper should expose runtime-state active query")
	_expect(active_body.find("_active_unlock_flight.is_active_from_runtime_state") >= 0, "runtime perk state should route active flight query through runtime-state facade")
	_expect(active_body.find("choice_flight_effect") < 0, "runtime perk state should not pass flight effect directly for active query")
	_expect(confirm_flow_source.find("apply_effect_state_update") >= 0, "confirm-flow helper should delegate flight state writes")
	_expect(confirm_flow_source.find("consume_effect") >= 0, "confirm-flow helper should delegate flight effect consumption")
	_expect(finish_body.find("build_landing_payload") >= 0, "confirm-flow helper should delegate flight landing payload validation")
	_expect(state_source.find("choice_flight_effect = effect") < 0, "runtime perk state should not assign flight effect inline")
	_expect(update_body.find("choice_flight_effect.duplicate(true)") < 0, "runtime perk state should not duplicate flight effects inline")
	_expect(update_body.find("_active_unlock_flight.reset(choice_flight_effect)") < 0, "runtime perk state should not reset consumed flight effects inline")
	_expect(update_body.find("effect.get(\"choice\"") < 0, "runtime perk state should not parse landing choice from flight effect inline")
	_expect(update_body.find("effect.get(\"choice_id\"") < 0, "runtime perk state should not parse landing choice id inline")


func _verify_active_unlock_flight_selected_card_builder() -> void:
	var helper := RuntimePerkActiveUnlockFlight.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var choice := {
		"id": "unlock_plasma",
		"name": "plasma",
		"unlocks_skill": "plasma",
		"character_restriction": "smasher",
		"icon_color": Color(0.0, 0.78, 1.0),
	}
	var rects := [
		Rect2(Vector2(110.0, 140.0), Vector2(180.0, 120.0)),
		Rect2(Vector2(340.0, 140.0), Vector2(180.0, 120.0)),
	]
	var effect: Dictionary = helper.build_effect_for_selected_card(choice, 1, rects, owner, registry, view_size)
	_expect(bool(effect.get("active", false)), "selected-card builder should create an active flight")
	_expect(str(effect.get("skill_id", "")) == "plasma", "selected-card builder should preserve the unlocked skill id")
	_expect(_get_vector2(effect.get("source_pos", Vector2.ZERO)) == rects[1].get_center(), "selected-card builder should use the selected card center")
	_expect(helper.build_effect_for_selected_card(choice, -1, rects, owner, registry, view_size).is_empty(), "selected-card builder should reject negative selected indices")
	_expect(helper.build_effect_for_selected_card(choice, rects.size(), rects, owner, registry, view_size).is_empty(), "selected-card builder should reject out-of-range selected indices")
	_expect(helper.build_effect_for_selected_card({}, 0, rects, owner, registry, view_size).is_empty(), "selected-card builder should reject choices without an unlocked skill")
	var layout_state: Dictionary = helper.build_layout_state_from_runtime_state(FakeFlightState.new(), registry, view_size)
	_expect(not layout_state.is_empty(), "runtime-state layout facade should build a visible game layout")
	_expect(float(layout_state.get("width", 0.0)) > 0.0, "runtime-state layout facade should preserve game width")
	_expect(float(layout_state.get("height", 0.0)) > 0.0, "runtime-state layout facade should preserve game height")
	_expect(helper.build_layout_state_from_runtime_state(null, registry, view_size).is_empty(), "runtime-state layout facade should reject missing state")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var confirm_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
	var layout_body: String = _function_body(state_source, "func _build_flight_layout_state(")
	_expect(state_source.find("_choice_confirm_flow.choose_selected") >= 0, "runtime perk state should route selected-card flight construction through confirm-flow")
	_expect(confirm_flow_source.find("build_effect_for_selected_card") >= 0, "confirm-flow helper should delegate selected-card flight construction")
	_expect(helper_source.find("func build_layout_state_from_runtime_state(") >= 0, "active unlock flight helper should expose runtime-state layout facade")
	_expect(layout_body.find("_active_unlock_flight.build_layout_state_from_runtime_state") >= 0, "runtime perk state should route flight layout through runtime-state facade")
	_expect(layout_body.find("_active_unlock_flight.build_layout_state(") < 0, "runtime perk state should not consume raw flight layout builder")
	_expect(state_source.find("selected_index < 0 or selected_index >= rects.size()") < 0, "runtime perk state should not own selected-card bounds checks")
	_expect(state_source.find("var source_rect: Rect2 = rects[selected_index]") < 0, "runtime perk state should not extract the selected-card source rect inline")


func _verify_active_unlock_flight_advance_helper() -> void:
	var helper := RuntimePerkActiveUnlockFlight.new()
	_expect(not helper.advance({}, 1.0), "flight advance helper should ignore empty effects")
	var inactive_effect := {"active": false, "age": 0.0, "duration": 0.1}
	_expect(not helper.advance(inactive_effect, 1.0), "flight advance helper should ignore inactive effects")
	_expect(is_equal_approx(float(inactive_effect.get("age", 0.0)), 0.0), "flight advance helper should not mutate inactive effect age")
	var active_effect := {"active": true, "age": 0.0, "duration": 0.5}
	_expect(not helper.advance(active_effect, 0.2), "flight advance helper should keep unfinished flights active")
	_expect(is_equal_approx(float(active_effect.get("age", 0.0)), 0.2), "flight advance helper should advance active effect age")
	_expect(helper.advance(active_effect, 0.3), "flight advance helper should finish at duration")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var confirm_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var update_body: String = _function_body(state_source, "func _update_choice_flight_effect(")
	_expect(update_body.find("choice_flight_effect.is_empty()") < 0, "runtime perk state should not inspect flight effect emptiness before advance")
	_expect(update_body.find("_choice_confirm_flow.update_choice_flight_effect") >= 0, "runtime perk state should route flight advancement through confirm-flow")
	_expect(confirm_flow_source.find("advance(choice_flight_effect") >= 0, "confirm-flow helper should delegate flight advancement")


func _verify_active_unlock_waits_for_orb_flight() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var choice := {
		"id": "unlock_plasma",
		"name": "플라즈마",
		"unlocks_skill": "plasma",
		"character_restriction": "smasher",
		"icon_color": Color(0.0, 0.78, 1.0),
		"tree": "unlock",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
	}
	state.pending_skill_choices = 1
	state.choice_active = true
	state.current_choices = [choice]
	state.selected_index = 0
	state.animation_time = 0.5

	state.choose_selected(owner, registry, view_size)

	_expect(state.is_choice_active(), "active unlock choice should keep the modal alive during orb-flight")
	_expect(state.is_choice_flight_active(), "active unlock choice should start the skill-orb flight animation")
	_expect(registry.skill_config.unlock_calls == 0, "skill should not equip until the flight lands")
	_expect(not registry.skill_config.equipped_skills.has("plasma"), "plasma should not appear in the orb list before landing")
	_expect(registry.game_audio.item_get_calls == 1, "skill-orb flight should play the original item-get style cue once")
	_expect(registry.game_audio.weapon_change_calls == 0, "non-Commando active unlocks should not play the firearm weapon.wav cue")
	var flight: Dictionary = state.get_snapshot().get("choice_flight_effect", {})
	_expect(str(flight.get("skill_id", "")) == "plasma", "flight payload should target the unlocked skill id")
	_expect(int(flight.get("target_slot_index", -1)) == 2, "flight should target the first empty skill orb slot")
	_expect(_get_vector2(flight.get("source_pos", Vector2.ZERO)) != Vector2.ZERO, "flight should keep the selected card source point")
	_expect(_get_vector2(flight.get("target_pos", Vector2.ZERO)) != Vector2.ZERO, "flight should resolve a visible skill-orb target point")
	var flight_particles_value: Variant = flight.get("particles", [])
	var flight_particles: Array = flight_particles_value if flight_particles_value is Array else []
	_expect(RuntimePerkState.PARTICLE_COUNT <= 20, "choice modal ambient particles should stay within the tightened post-select render budget")
	_expect(RuntimePerkState.ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT <= 18, "active unlock flight particles should stay within the tightened post-select render budget")
	_expect(RuntimePerkOverlayRenderer.CHOICE_MODAL_PARTICLE_DRAW_LIMIT <= 10, "choice modal particle draw should stay capped")
	_expect(RuntimePerkOverlayRenderer.CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO >= 0.68, "choice modal particles should keep compact halo work late in lifetime")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT <= 6, "active unlock flight should draw a tighter particle subset")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_SOURCE_RING_COUNT <= 1, "choice flight source burst should stay compact")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_ARRIVAL_RING_COUNT <= 1, "choice flight arrival burst should stay compact")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_SOURCE_ARC_SEGMENTS <= 10, "choice flight source arcs should stay within budget")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_CORE_ARC_SEGMENTS <= 8, "choice flight core arc should stay within budget")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_ARRIVAL_ARC_SEGMENTS <= 10, "choice flight arrival arcs should stay within budget")
	_expect(flight_particles.size() <= RuntimePerkState.ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT, "flight payload should respect the active unlock particle cap")

	state.update(0.50, view_size, owner, registry)
	_expect(registry.skill_config.unlock_calls == 0, "mid-flight should still be pre-equip")
	_expect(state.is_choice_flight_active(), "flight should still be active before its landing window")

	state.update(2.0, view_size, owner, registry)
	_expect(registry.skill_config.unlock_calls == 1, "flight landing should equip the unlocked skill")
	_expect(registry.skill_config.equipped_skills.has("plasma"), "plasma should be registered into the skill orb list after landing")
	_expect(not state.is_choice_active(), "modal should close after the landing applies the unlock")
	_expect(not state.is_choice_flight_active(), "flight state should clear after landing")
	_expect(state.pending_skill_choices == 0, "successful unlock should consume one pending perk choice")
	_expect(int(state.runtime_skill_levels.get("unlock_plasma", 0)) == 1, "unlock perk level should be committed after landing")
	_expect(not registry.has_requested_key("commando_weapon_controller"), "smasher unlock should not instantiate or sync the commando weapon controller")


func _verify_active_unlock_chain_reopens_with_input_guard() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var unlock_choice := {
		"id": "unlock_plasma",
		"name": "plasma",
		"unlocks_skill": "plasma",
		"character_restriction": "smasher",
		"icon_color": Color(0.0, 0.78, 1.0),
		"tree": "unlock",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
	}
	registry.runtime_perk_catalog.choices = [
		_build_basic_choice("dash_training"),
		_build_basic_choice("guard_training"),
		_build_basic_choice("speed_training"),
	]
	state.pending_skill_choices = 2
	state.choice_active = true
	state.current_choices = [unlock_choice]
	state.selected_index = 0
	state.animation_time = 0.5

	state.choose_selected(owner, registry, view_size)
	_expect(state.is_choice_flight_active(), "chained active unlock should start the orb-flight before reopening choices")

	state.update(1.85, view_size, owner, registry)
	_expect(state.is_choice_flight_active(), "chained active unlock should still be flying just before landing")
	_expect(state.animation_time > 0.24, "orb-flight wait should accumulate old modal animation time before landing")

	state.update(0.02, view_size, owner, registry)
	_expect(registry.skill_config.equipped_skills.has("plasma"), "chained active unlock should equip the skill on landing")
	_expect(not state.is_choice_flight_active(), "chained active unlock should clear the flight on landing")
	_expect(state.is_choice_active(), "chained active unlock should open the next perk-choice modal")
	_expect(state.pending_skill_choices == 1, "chained active unlock should leave one pending choice after opening the next modal")
	_expect(state.current_choices.size() == 3, "chained active unlock should populate the next modal from the catalog")
	_expect(
		state.animation_time < 0.24,
		"new chained modal should keep its input guard instead of inheriting the old modal animation time"
	)
	_expect(not state.is_selectable(), "new chained modal should not be selectable on its first landing frame")


func _verify_soldier_unlock_syncs_commando_controller() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var registry := FakeRegistry.new()
	registry.commando_skill_config.equipped_skills = ["commando_pistol"]
	var choice := {
		"id": "soldier_unlock_ak47",
		"name": "AK-47",
		"unlocks_skill": "ak47",
		"character_restriction": "soldier",
		"icon_color": Color(1.0, 0.7, 0.2),
		"tree": "unlock",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
	}

	_expect(state.apply_choice(choice, owner, registry), "soldier unlock should apply")
	_expect(registry.commando_skill_config.unlock_calls == 1, "soldier unlock should equip through the commando skill config")
	_expect(registry.commando_skill_config.equipped_skills.has("ak47"), "soldier unlock should enter the shared firearm slots")
	_expect(registry.commando_weapon_controller.sync_calls == 1, "soldier unlock should still sync the commando weapon controller")
	_expect(registry.commando_weapon_controller.last_skill_config == registry.commando_skill_config, "commando sync should receive the soldier skill config")
	_expect(registry.commando_weapon_controller.highlight_calls == 1, "soldier firearm unlock should pulse the firearm HUD highlight")
	_expect(registry.commando_weapon_controller.last_highlight_skill == "ak47", "soldier firearm HUD highlight should target the unlocked weapon")
	_expect(registry.game_audio.weapon_change_calls == 1, "soldier firearm unlock should play weapon.wav")
	_expect(int(state.runtime_skill_levels.get("soldier_unlock_ak47", 0)) == 1, "soldier unlock level should be committed")


func _verify_result_box_dimension_gate_waits_for_next_spawn_intro_finish() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	registry.runtime_perk_catalog.choices = [{
		"id": "instant_dimension_gate",
		"name": "차원개방",
		"is_instant": true,
		"icon_color": Color(0.52, 0.86, 1.0),
	}]
	state.pending_skill_choices = 1
	state.open_next_choice(
		"smasher",
		registry.runtime_perk_catalog,
		false,
		owner,
		registry,
		null,
		{RuntimePerkState.CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END: true}
	)
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "deferred dimension-gate choice should close the modal after selection")
	_expect(state.has_pending_dimension_gate_after_spawn_intro(), "result-box dimension gate should queue after the selection")
	_expect(registry.active_item_runtime.dimension_gate_calls == 0, "dimension gate should not activate on the result screen")

	var same_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(same_stage_result.get("wait_for_stage_advance", false)), "queued dimension gate should wait until the stage has advanced")
	_expect(registry.active_item_runtime.dimension_gate_calls == 0, "same-stage intro finish should not consume result-box dimension gate")
	_expect(state.has_pending_dimension_gate_after_spawn_intro(), "same-stage intro finish should keep the queued dimension gate")

	owner.current_stage = 2
	var next_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(next_stage_result.get("dimension_gate_activated", false)), "next-stage spawn intro finish should activate queued dimension gate")
	_expect(registry.active_item_runtime.dimension_gate_calls == 1, "dimension gate should activate exactly once after the next spawn intro")
	_expect(not state.has_pending_dimension_gate_after_spawn_intro(), "activated dimension gate should clear the queued effect")


func _verify_result_box_full_gauge_waits_for_next_spawn_intro_finish() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	owner.special_gauge = 120.0
	registry.runtime_perk_catalog.choices = [{
		"id": "instant_gauge_full",
		"name": "풀게이징",
		"is_instant": true,
		"icon_color": Color(1.0, 0.9, 0.25),
	}]
	state.pending_skill_choices = 1
	state.open_next_choice(
		"smasher",
		registry.runtime_perk_catalog,
		false,
		owner,
		registry,
		null,
		{RuntimePerkState.CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END: true}
	)
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "deferred full-gauge choice should close the modal after selection")
	_expect(state.has_pending_full_gauge_after_spawn_intro(), "result-box full gauge should queue after the selection")
	_expect(is_equal_approx(owner.special_gauge, 120.0), "full gauge should not fill gauge on the result screen")
	_expect(registry.smasher_dash_state.refill_calls == 0, "full gauge should not refill dash tokens on the result screen")
	_expect(registry.skill_config.reset_cooldown_calls == 0, "full gauge should not reset cooldowns on the result screen")

	var same_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(same_stage_result.get("wait_for_stage_advance", false)), "queued full gauge should wait until the stage has advanced")
	_expect(is_equal_approx(owner.special_gauge, 120.0), "same-stage intro finish should not consume queued full gauge")
	_expect(state.has_pending_full_gauge_after_spawn_intro(), "same-stage intro finish should keep the queued full gauge")

	owner.current_stage = 2
	var next_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(next_stage_result.get("full_gauge_activated", false)), "next-stage spawn intro finish should activate queued full gauge")
	_expect(is_equal_approx(owner.special_gauge, 500.0), "queued full gauge should fill special gauge after the next spawn intro")
	_expect(registry.smasher_dash_state.refill_calls == 1, "queued full gauge should refill dash tokens after the next spawn intro")
	_expect(registry.skill_config.reset_cooldown_calls == 1, "queued full gauge should reset cooldowns after the next spawn intro")
	_expect(not state.has_pending_full_gauge_after_spawn_intro(), "activated full gauge should clear the queued effect")


func _verify_starpoint_collection_update_helper() -> void:
	var helper := RuntimePerkStarpointAbsorption.new()
	var update: Dictionary = helper.build_collection_update(3, 0, 1, RuntimePerkState.STARPOINT_PER_SKILL_CHOICE)
	_expect(int(update.get("next_pending_skill_choices", 0)) == 4, "starpoint collection helper should convert collected points into pending choices")
	_expect(int(update.get("next_starpoint_for_skills", -1)) == 0, "starpoint collection helper should expose the starpoint remainder")
	_expect(int(update.get("granted_choices", 0)) == 3, "starpoint collection helper should expose granted choice count")
	_expect(str(update.get("feedback_text", "")) == "\uc2a4\ud0c0\ud3ec\uc778\ud2b8 +3", "starpoint collection helper should own collection feedback text")
	_expect(is_equal_approx(float(update.get("feedback_timer", 0.0)), RuntimePerkStarpointAbsorption.COLLECTION_FEEDBACK_TIMER), "starpoint collection helper should own collection feedback timer")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var collection_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	_expect(state_source.find("RuntimePerkStarpointCollectionFlow") >= 0, "runtime perk state should use the starpoint collection-flow helper")
	_expect(collection_flow_source.find("build_collection_update") >= 0, "starpoint collection flow should use the starpoint collection helper")
	_expect(state_source.find("while starpoint_for_skills >=") < 0, "runtime perk state should not own starpoint-to-choice conversion loop")
	_expect(state_source.find("\"스타포인트 +%d\"") < 0, "runtime perk state should not own starpoint collection feedback text")


func _verify_collect_starpoints_preserves_in_flight_drops() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.runtime_perk_catalog.choices = [_build_basic_choice("stability_training")]

	var opened: bool = state.collect_star_points(1, "smasher", registry.runtime_perk_catalog, owner, registry)

	_expect(opened, "collecting a full starpoint should open the perk choice modal")
	_expect(state.is_choice_active(), "starpoint collection should activate the perk choice modal")
	_expect(state.pending_skill_choices == 1, "starpoint collection should queue one pending choice")
	_expect(str(state.feedback_text) == "\uc2a4\ud0c0\ud3ec\uc778\ud2b8 +1", "starpoint collection should apply helper-owned feedback text")
	_expect(is_equal_approx(float(state.feedback_timer), RuntimePerkStarpointAbsorption.COLLECTION_FEEDBACK_TIMER), "starpoint collection should apply helper-owned feedback timer")
	_expect(not registry.stage1_balloon_event.starpoint_drops.is_empty(), "Stage 1 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage1_balloon_event.starpoint_particles.is_empty(), "Stage 1 starpoint particles should survive the modal open")
	_expect(not registry.stage2_pillar_background.starpoint_drops.is_empty(), "Stage 2 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage2_pillar_background.starpoint_particles.is_empty(), "Stage 2 starpoint particles should survive the modal open")
	_expect(not registry.stage3_boss_skill_state.starpoint_drops.is_empty(), "Stage 3 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage3_boss_skill_state.starpoint_particles.is_empty(), "Stage 3 starpoint particles should survive the modal open")
	_expect(not registry.stage4_bird_event.starpoint_drops.is_empty(), "Stage 4 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage4_bird_event.starpoint_particles.is_empty(), "Stage 4 starpoint particles should survive the modal open")


func _verify_starpoint_absorption_tracks_player_after_choice() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var renderer := RuntimePerkOverlayRenderer.new()

	state.pending_skill_choices = 1
	state.choice_active = true
	state.current_choices = [_build_basic_choice("stability_training")]
	state.selected_index = 0
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "ordinary perk choice should close the modal immediately")
	_expect(state.is_starpoint_absorption_active(), "closing the final perk choice should start the starpoint absorption effect")
	_expect(renderer._runtime_state_has_visible_effects(state), "runtime perk overlay should stay visible for the post-modal absorption effect")
	var snapshot: Dictionary = state.get_snapshot()
	var selected_choice: Dictionary = _get_dict(snapshot.get("last_selected_choice", {}))
	_expect(str(selected_choice.get("id", "")) == "stability_training", "state should remember the last selected perk choice")
	_expect(int(snapshot.get("selected_choice_sequence", 0)) == 1, "state should bump selected choice sequence after a successful choice")

	state.update(0.016, view_size, owner, registry)
	var first_effect: Dictionary = _get_dict(state.get_snapshot().get("starpoint_absorption_effect", {}))
	var first_source: Vector2 = _get_vector2(first_effect.get("source_pos", Vector2.ZERO))
	var first_target: Vector2 = _get_vector2(first_effect.get("target_pos", Vector2.ZERO))
	_expect(first_source != Vector2.ZERO, "absorption update should resolve a visible source point")
	_expect(first_target != Vector2.ZERO, "absorption update should resolve a visible player target point")

	owner.player_pos.x += 40.0
	state.update(0.016, view_size, owner, registry)
	var moved_effect: Dictionary = _get_dict(state.get_snapshot().get("starpoint_absorption_effect", {}))
	var moved_target: Vector2 = _get_vector2(moved_effect.get("target_pos", Vector2.ZERO))
	_expect(moved_target.x > first_target.x, "absorption target should keep tracking the moving player paddle")

	state.update(1.0, view_size, owner, registry)
	_expect(not state.is_starpoint_absorption_active(), "absorption effect should clear after its duration")


func _build_basic_choice(choice_id: String) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"character_restriction": "smasher",
		"icon_color": Color(0.45, 0.75, 1.0),
		"tree": "training",
		"max_level": 5,
		"current_level": 0,
		"next_level": 1,
	}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
