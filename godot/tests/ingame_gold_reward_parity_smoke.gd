extends SceneTree

const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const RuntimePerkGoldAwards := preload("res://scripts/characters/runtime_perk_gold_awards.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherComboState := preload("res://scripts/characters/smasher_combo_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")

var _failures: Array[String] = []


class FakeViperSkillRuntime:
	extends RefCounted

	var contact_count := 0

	func register_player_ball_contact(_deps: Dictionary, _context: Dictionary) -> void:
		contact_count += 1

	func apply_shadow_step_paddle_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
		var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
		var runtime_perk_gold := 0
		if runtime_perk_state != null and runtime_perk_state.has_method("award_gold"):
			runtime_perk_gold = int(runtime_perk_state.award_gold(80, context, deps))
		return {
			"hit": true,
			"ball_vel": ball_vel,
			"runtime_perk_gold": runtime_perk_gold,
		}


class FakeRuntimePerkState:
	extends RefCounted

	var gold_from_perks := 0
	var feedback_text := "old"
	var feedback_timer := 0.25
	var item_gold_gain_multiplier := 1.0


func _init() -> void:
	_verify_rally_gold_speed_table()
	_verify_gold_award_payload_builder()
	_verify_original_modifier_order()
	_verify_blacksmith_structure_bonus()
	_verify_dash_doubles_only_next_rally()
	_verify_player_paddle_hit_awards_rally_gold_with_pre_hit_combo()
	_verify_skill_hit_gold_suppresses_generic_rally_gold()

	if _failures.is_empty():
		print("ingame_gold_reward_parity_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_rally_gold_speed_table() -> void:
	var perk_state: Object = RuntimePerkState.new()
	_expect(perk_state.calculate_rally_gold(Vector2(7.0, 0.0)) == 4, "speed below 8 should award 4 rally gold")
	_expect(perk_state.calculate_rally_gold(Vector2(10.0, 0.0)) == 6, "speed below 12 should award 6 rally gold")
	_expect(perk_state.calculate_rally_gold(Vector2(14.0, 0.0)) == 8, "speed below 16 should award 8 rally gold")
	_expect(perk_state.calculate_rally_gold(Vector2(18.0, 0.0)) == 10, "speed below 20 should award 10 rally gold")
	_expect(perk_state.calculate_rally_gold(Vector2(22.0, 0.0)) == 12, "speed 20 or higher should award 12 rally gold")


func _verify_gold_award_payload_builder() -> void:
	var result: Dictionary = RuntimePerkGoldAwards.award_gold(
		10,
		5,
		{
			"selected_character_type": "smasher",
			"enraged_boss_active": true,
			"smasher_combo_count": 2,
		},
		{},
		1.5,
		true
	)
	_expect(int(result.get("awarded", 0)) == 112, "gold award helper should preserve modifier order")
	_expect(int(result.get("total", 0)) == 117, "gold award helper should add the boosted amount to the current total")
	_expect(bool(result.get("show_feedback", false)), "positive gold award helper should request feedback")
	_expect(str(result.get("feedback_text", "")) == "\ud37d \uace8\ub4dc +112", "gold award helper should own default feedback text")
	_expect(RuntimePerkGoldAwards.get_viper_ignition_aura_gold_bonus(true) == 50, "gold helper should expose active Ignition gold bonus")
	_expect(RuntimePerkGoldAwards.get_viper_ignition_aura_gold_bonus(false) == 0, "gold helper should suppress inactive Ignition gold bonus")
	var multiplier_update: Dictionary = RuntimePerkGoldAwards.build_item_gold_gain_multiplier_update(1.0, -2.0)
	_expect(bool(multiplier_update.get("changed", false)), "gold helper should mark clamped multiplier changes")
	_expect(is_equal_approx(float(multiplier_update.get("multiplier", -1.0)), 0.0), "gold helper should clamp negative item-gold multipliers")
	var unchanged_multiplier: Dictionary = RuntimePerkGoldAwards.build_item_gold_gain_multiplier_update(1.5, 1.5)
	_expect(not bool(unchanged_multiplier.get("changed", true)), "gold helper should report unchanged item-gold multipliers")

	var arena_result: Dictionary = RuntimePerkGoldAwards.award_rally_gold(
		Vector2(20.0, 0.0),
		37,
		{"arena_mode_enabled": true},
		{}
	)
	_expect(int(arena_result.get("total", 0)) == 37, "arena rally helper should preserve the current total")
	_expect(int(arena_result.get("awarded", -1)) == 0, "arena rally helper should not award runtime perk gold")
	_expect(not bool(arena_result.get("show_feedback", true)), "arena rally helper should not request feedback")

	var convert_result: Dictionary = RuntimePerkGoldAwards.award_convert_to_gold_choice(
		{"id": "convert_to_gold", "gold_amount": 500},
		70,
		FakeOwner.new("viper"),
		null,
		1.75,
		true
	)
	_expect(int(convert_result.get("awarded", 0)) == 962, "gold conversion helper should apply Ignition Aura before Gold Digger")
	_expect(int(convert_result.get("total", 0)) == 1032, "gold conversion helper should add the boosted conversion to the current total")
	_expect(is_equal_approx(float(convert_result.get("feedback_timer", 0.0)), 1.2), "gold conversion helper should keep the conversion feedback duration")
	_expect(str(convert_result.get("feedback_text", "")) == "\uace8\ub4dc +962", "gold conversion helper should own conversion feedback text")

	var state_update: Dictionary = RuntimePerkGoldAwards.build_state_update({"total": 20, "awarded": 0, "show_feedback": false}, 7)
	_expect(int(state_update.get("gold_from_perks", 0)) == 20, "gold update helper should expose the next stored total")
	_expect(not bool(state_update.get("has_feedback", true)), "zero-award gold update should not expose feedback")
	var fallback_feedback_update: Dictionary = RuntimePerkGoldAwards.build_state_update({"total": 15, "awarded": 10, "show_feedback": true, "feedback_text": ""}, 5)
	_expect(str(fallback_feedback_update.get("feedback_text", "")) == "\ud37d \uace8\ub4dc +10", "gold update helper should own default feedback fallback")
	var preserved_feedback_application: Dictionary = RuntimePerkGoldAwards.build_state_application(
		{"total": 20, "awarded": 0, "show_feedback": false},
		7,
		"keep me",
		0.75
	)
	_expect(int(preserved_feedback_application.get("gold_from_perks", 0)) == 20, "gold application helper should expose the next stored total")
	_expect(str(preserved_feedback_application.get("feedback_text", "")) == "keep me", "gold application helper should preserve feedback text without new feedback")
	_expect(is_equal_approx(float(preserved_feedback_application.get("feedback_timer", 0.0)), 0.75), "gold application helper should preserve feedback timer without new feedback")
	var live_state := FakeRuntimePerkState.new()
	var live_application: Dictionary = RuntimePerkGoldAwards.apply_state_application(live_state, preserved_feedback_application)
	_expect(bool(live_application.get("accepted", false)), "gold live-state application should accept valid state objects")
	_expect(live_state.gold_from_perks == 20, "gold live-state application should write stored perk gold")
	_expect(str(live_application.get("feedback_text", "")) == "keep me", "gold live-state application should preserve feedback text")
	_expect(is_equal_approx(float(live_application.get("feedback_timer", 0.0)), 0.75), "gold live-state application should preserve feedback timer")
	var full_apply_state := FakeRuntimePerkState.new()
	var full_apply: Dictionary = RuntimePerkGoldAwards.apply_award_result_to_runtime_state(
		full_apply_state,
		{"total": 33, "awarded": 13, "show_feedback": true, "feedback_text": "Gold!", "feedback_timer": 1.1},
		Callable(self, "_apply_fake_feedback")
	)
	_expect(bool(full_apply.get("accepted", false)), "gold award result application should accept valid runtime state")
	_expect(full_apply_state.gold_from_perks == 33, "gold award result application should write stored perk gold")
	_expect(str(full_apply_state.feedback_text) == "Gold!", "gold award result application should route feedback through the provided callback")
	_expect(is_equal_approx(float(full_apply_state.feedback_timer), 1.1), "gold award result application should route feedback timer through the provided callback")
	_expect(not bool(RuntimePerkGoldAwards.apply_award_result_to_runtime_state(null, {}, Callable(self, "_apply_fake_feedback")).get("accepted", true)), "gold award result application should reject missing state")
	var live_multiplier: Dictionary = RuntimePerkGoldAwards.apply_item_gold_gain_multiplier_update(live_state, multiplier_update)
	_expect(bool(live_multiplier.get("accepted", false)), "gold multiplier live-state application should accept multiplier updates")
	_expect(is_equal_approx(live_state.item_gold_gain_multiplier, 0.0), "gold multiplier live-state application should write clamped multipliers")
	_expect(not bool(RuntimePerkGoldAwards.apply_state_application(null, preserved_feedback_application).get("accepted", true)), "gold live-state application should reject missing state")
	_expect(not bool(RuntimePerkGoldAwards.apply_item_gold_gain_multiplier_update(null, multiplier_update).get("accepted", true)), "gold multiplier live-state application should reject missing state")


func _verify_original_modifier_order() -> void:
	var perk_state: Object = RuntimePerkState.new()
	perk_state.set_viper_ignition_aura_active(true)
	perk_state.set_item_gold_gain_multiplier(1.5)
	var awarded: int = perk_state.award_gold(
		10,
		{
			"selected_character_type": "smasher",
			"enraged_boss_active": true,
			"smasher_combo_count": 2,
		},
		{}
	)
	_expect(awarded == 112, "gold modifiers should keep Python order: enraged, Ignition Aura, Gold Digger, Smasher combo")
	_expect(perk_state.gold_from_perks == 112, "stored perk gold should match modified award")
	_expect(str(perk_state.feedback_text) == "\ud37d \uace8\ub4dc +112", "state should apply helper-owned gold feedback text")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_gold_award_flow.gd")
	_expect(state_source.find("RuntimePerkGoldAwardFlow") >= 0, "state should delegate gold award orchestration to the flow helper")
	_expect(flow_source.find("RuntimePerkGoldAwards.apply_award_result_to_runtime_state") >= 0, "gold award flow should apply gold awards through helper-owned award result application")
	_expect(flow_source.find("RuntimePerkGoldAwards.get_viper_ignition_aura_gold_bonus") >= 0, "gold award flow should query helper-owned Ignition gold bonus")
	_expect(flow_source.find("RuntimePerkGoldAwards.build_item_gold_gain_multiplier_update") >= 0, "gold award flow should apply helper-owned item-gold multiplier updates")
	_expect(flow_source.find("RuntimePerkGoldAwards.apply_item_gold_gain_multiplier_update") >= 0, "gold award flow should delegate item-gold multiplier state application")
	var apply_gold_body: String = _function_body(state_source, "func _apply_gold_award_result(")
	_expect(apply_gold_body.find("_gold_award_flow.apply_gold_award_result") >= 0, "gold award wrapper should delegate award-result application to the flow helper")
	_expect(apply_gold_body.find("RuntimePerkGoldAwards.apply_award_result_to_runtime_state") < 0, "state should not wire gold award result feedback inline")
	_expect(apply_gold_body.find("RuntimePerkGoldAwards.build_state_application") < 0, "gold award wrapper should not build gold state application inline")
	_expect(apply_gold_body.find("RuntimePerkGoldAwards.apply_state_application") < 0, "gold award wrapper should not apply live gold state inline")
	_expect(apply_gold_body.find("_choice_feedback.apply_feedback_state_update") < 0, "gold award wrapper should not apply gold feedback inline")
	var award_gold_body: String = _function_body(state_source, "func award_gold(")
	_expect(award_gold_body.find("_gold_award_flow.award_gold") >= 0, "state should route skill-gold awards through the flow helper")
	_expect(award_gold_body.find("RuntimePerkGoldAwards.award_gold") < 0, "state should not build skill-gold awards inline")
	var award_rally_body: String = _function_body(state_source, "func award_rally_gold(")
	_expect(award_rally_body.find("_gold_award_flow.award_rally_gold") >= 0, "state should route rally-gold awards through the flow helper")
	_expect(award_rally_body.find("RuntimePerkGoldAwards.award_rally_gold") < 0, "state should not build rally-gold awards inline")
	_expect(state_source.find("RuntimePerkGoldAwards.build_state_update") < 0, "state should not own the gold state-update extraction step")
	_expect(state_source.find("RuntimePerkGoldAwards.format_default_gold_feedback") < 0, "state should not own default gold feedback fallback")
	_expect(state_source.find("VIPER_IGNITION_AURA_GOLD_BONUS if viper_ignition_aura_active") < 0, "state should not inline Ignition gold bonus policy")
	_expect(state_source.find("item_gold_gain_multiplier = max(0.0, float(multiplier))") < 0, "state should not inline item-gold multiplier clamp policy")
	_expect(state_source.find("gold_from_perks = int(state_update.get") < 0, "state should not write gold award totals inline")
	_expect(state_source.find("item_gold_gain_multiplier = float(update.get") < 0, "state should not write item-gold multipliers inline")


func _verify_blacksmith_structure_bonus() -> void:
	var perk_state: Object = RuntimePerkState.new()
	var awarded: int = perk_state.award_gold(
		100,
		{
			"selected_character_type": "blacksmith",
			"blacksmith_divine_stone_active": true,
			"blacksmith_turret_active": true,
		},
		{}
	)
	_expect(awarded == 130, "active Blacksmith divine stone and turret should add two 15 percent gold bonuses")


func _verify_dash_doubles_only_next_rally() -> void:
	var perk_state: Object = RuntimePerkState.new()
	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, null, null, false), "dash should start in smoke setup")
	_expect(bool(dash_state.get_snapshot().get("next_rally_gold_multiplier_armed", false)), "dash should arm next rally gold multiplier")

	var first_total: int = perk_state.award_rally_gold(Vector2(10.0, 0.0), {}, {"dash_state": dash_state})
	var second_total: int = perk_state.award_rally_gold(Vector2(10.0, 0.0), {}, {"dash_state": dash_state})
	_expect(first_total == 12, "first post-dash rally should double 6 gold to 12")
	_expect(second_total == 18, "second rally should add only the normal 6 gold after the dash multiplier is consumed")
	_expect(not bool(dash_state.get_snapshot().get("next_rally_gold_multiplier_armed", false)), "dash gold multiplier should be consumed once")


func _verify_player_paddle_hit_awards_rally_gold_with_pre_hit_combo() -> void:
	var handler: Object = PaddleBouncePostHitHandler.new()
	var perk_state: Object = RuntimePerkState.new()
	var combo_state: Object = SmasherComboState.new()
	var context: Dictionary = _base_hit_context("smasher")
	var deps: Dictionary = {
		"runtime_perk_state": perk_state,
		"combo_state": combo_state,
	}
	var expected_totals := [12, 24, 37]
	for hit_index in range(expected_totals.size()):
		var result: Dictionary = handler.apply(
			true,
			Vector2(320.0, 650.0),
			Vector2(22.0, 0.0),
			0.0,
			155.0,
			false,
			false,
			false,
			0.0,
			0.0,
			false,
			false,
			0.0,
			context,
			deps
		)
		_expect(
			int(result.get("runtime_perk_gold", -1)) == int(expected_totals[hit_index]),
			"player paddle hit %d should award rally gold using pre-hit Smasher combo count" % (hit_index + 1)
		)
	_expect(combo_state.get_combo_count() == 3, "player paddle hits should still advance Smasher combo state")
	_expect(perk_state.gold_from_perks == 37, "three rally hits should store the expected cumulative gold")


func _verify_skill_hit_gold_suppresses_generic_rally_gold() -> void:
	var handler: Object = PaddleBouncePostHitHandler.new()
	var perk_state: Object = RuntimePerkState.new()
	var viper_runtime := FakeViperSkillRuntime.new()
	var context: Dictionary = _base_hit_context("viper")
	var deps: Dictionary = {
		"runtime_perk_state": perk_state,
		"viper_skill_runtime": viper_runtime,
	}
	var result: Dictionary = handler.apply(
		true,
		Vector2(320.0, 650.0),
		Vector2(22.0, 0.0),
		0.0,
		155.0,
		false,
		false,
		false,
		0.0,
		0.0,
		false,
		false,
		0.0,
		context,
		deps
	)
	_expect(viper_runtime.contact_count == 1, "viper contact path should run in the suppression smoke")
	_expect(int(result.get("runtime_perk_gold", -1)) == 80, "skill hit should expose only its skill gold")
	_expect(perk_state.gold_from_perks == 80, "generic rally gold should not be added after a skill-specific gold hit")


func _base_hit_context(character_type: String) -> Dictionary:
	return {
		"selected_character_type": character_type,
		"current_stage": 1,
		"player_y": 700.0,
		"ball_size": 28.6,
		"player_speed": 0.0,
		"boss_vel": 0.0,
		"gauge_charge_per_hit": 0.0,
		"gauge_max": 500.0,
		"player_has_hit_sprite": false,
		"boss_has_hit_sprite": false,
		"paddle_width": 155.0,
	}


func _apply_fake_feedback(runtime_state: Object, update: Dictionary, fallback_timer: float = 0.0) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	runtime_state.set("feedback_text", str(update.get("feedback_text", "")))
	runtime_state.set("feedback_timer", float(update.get("feedback_timer", fallback_timer)))
	return {
		"accepted": true,
		"feedback_text": str(runtime_state.get("feedback_text")),
		"feedback_timer": float(runtime_state.get("feedback_timer")),
	}


class FakeOwner:
	extends RefCounted

	var selected_character_type := ""

	func _init(character_type: String) -> void:
		selected_character_type = character_type


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
