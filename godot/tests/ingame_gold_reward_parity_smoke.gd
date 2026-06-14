extends SceneTree

const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
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


func _init() -> void:
	_verify_rally_gold_speed_table()
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
