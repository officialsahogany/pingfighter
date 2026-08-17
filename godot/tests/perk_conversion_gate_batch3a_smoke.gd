extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const VALUE_CASES := [
	{"id": "adversity_armor", "key": "trigger_chance_pct", "fixture": 30.0, "getter": "get_adversity_armor_trigger_chance_pct"},
	{"id": "adversity_armor", "key": "invincible_duration_sec", "fixture": 8.0, "getter": "get_adversity_armor_invincible_duration_sec"},
	{"id": "shrapnel_armor", "key": "trigger_chance_pct", "fixture": 15.0, "getter": "get_shrapnel_armor_trigger_chance_pct"},
	{"id": "shrapnel_armor", "key": "shard_count", "fixture": 7.0, "getter": "get_shrapnel_armor_shard_count"},
	{"id": "shrapnel_armor", "key": "knockback_level", "fixture": 3.0, "getter": "get_shrapnel_armor_knockback_level"},
	{"id": "shrapnel_armor", "key": "gauge_cost", "fixture": 35.0, "getter": "get_shrapnel_armor_gauge_cost"},
	{"id": "rainbow_fur_glove", "key": "rainbow_glove_trigger_chance_pct", "fixture": 9.0, "getter": "get_rainbow_fur_glove_trigger_chance_pct"},
	{"id": "rainbow_fur_glove", "key": "rainbow_glove_cooldown_reduction_pct", "fixture": 44.0, "getter": "get_rainbow_fur_glove_cooldown_reduction_pct"},
	{"id": "venom_mist_gauntlet", "key": "mist_trigger_chance_pct", "fixture": 45.0, "getter": "get_venom_mist_trigger_chance_pct"},
	{"id": "venom_mist_gauntlet", "key": "mist_duration_sec", "fixture": 4.0, "getter": "get_venom_mist_duration_sec"},
]


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var selected_character_type := "smasher"
	var current_stage := 1
	var player_pos := Vector2(302.5, 690.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var boss_paddle_size := Vector2(100.0, 40.0)
	var ball_pos := Vector2(380.0, 360.0)
	var ball_active := true
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeRegistry:
	extends RefCounted

	var mythic_item_runtime: Object
	var runtime_perk_state: Object
	var game_audio: Object
	var battle_feedback_state: Object

	func _init(runtime_ref: Object, state_ref: Object = null, audio_ref: Object = null, feedback_ref: Object = null) -> void:
		mythic_item_runtime = runtime_ref
		runtime_perk_state = state_ref
		game_audio = audio_ref
		battle_feedback_state = feedback_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"game_audio":
				return game_audio
			"battle_feedback_state":
				return battle_feedback_state
		return null


class FakeAudio:
	extends RefCounted

	var active_item_calls := 0
	var soul_burst_calls := 0
	var shrapnel_fire_calls := 0
	var rainbow_calls := 0

	func play_active_item() -> void:
		active_item_calls += 1

	func play_item_get() -> void:
		active_item_calls += 1

	func play_soul_burst_dash() -> void:
		soul_burst_calls += 1

	func play_shrapnel_armor_fire() -> void:
		shrapnel_fire_calls += 1

	func play_rainbow_fur_glove() -> void:
		rainbow_calls += 1


class FakeFeedback:
	extends RefCounted

	var gauge_flash_calls := 0
	var shake_calls := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1


class FakeSkillState:
	extends RefCounted

	var reduction_calls := 0
	var last_fraction := 0.0
	var last_msec := 0

	func reduce_all_cooldowns_by_fraction(reduction_fraction: float, current_msec: int) -> int:
		reduction_calls += 1
		last_fraction = reduction_fraction
		last_msec = current_msec
		return 1


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_off_flag_keeps_item_rolls()
	_verify_rainbow_balance_curve()
	_verify_on_flag_uses_perk_levels()
	_verify_on_flag_level_zero_is_inactive()
	_verify_on_flag_item_only_is_inactive()
	_verify_on_flag_perk_replaces_item_without_max()
	_verify_boolean_effect_gates()
	_verify_runtime_consumers_use_batch3a_getters()
	_verify_venom_guard_structure()
	_verify_overflow_saturates_at_consumer_limits()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_gate_batch3a_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_flag_keeps_item_rolls() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	for case_value in VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_item(runtime, str(case_data["id"]), {str(case_data["key"]): float(case_data["fixture"])}), "OFF fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			float(case_data["fixture"]),
			"OFF should keep item roll for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var soul_runtime: Object = _make_runtime({})
	_expect(_equip_item(soul_runtime, "soul_burst", {"soul_burst_gauge_cost": 140.0}), "OFF Soul Burst should equip")
	_expect_close(soul_runtime.get_soul_burst_gauge_cost(), 140.0, "OFF should keep Soul Burst item cost")
	_expect(soul_runtime.can_soul_burst_dash(140.0), "OFF Soul Burst should dash at rolled cost")

	var gravity_runtime: Object = _make_runtime({})
	_expect(_equip_item(gravity_runtime, "gravitybelt", {}), "OFF Gravity Belt should equip")
	_expect_close(_movement_speed_after_gravity_config(gravity_runtime), 6.0, "OFF Gravity Belt should produce instant movement")
	var speed_runtime: Object = _make_runtime({})
	_expect(_equip_item(speed_runtime, "speedgear", {}), "OFF Speedgear should equip")
	_expect_close(speed_runtime.get_speedgear_turn_decel_multiplier(), 2.5, "OFF Speedgear should keep fixed multiplier")
	_expect_close(_movement_speed_after_speedgear_config(speed_runtime), -1.0, "OFF Speedgear should feed turn-decel movement")


func _verify_rainbow_balance_curve() -> void:
	var expected_trigger_chances: Array[float] = [3.0, 4.0, 5.0, 6.0, 7.0]
	var expected_cooldown_reductions: Array[float] = [8.0, 11.0, 14.0, 17.0, 20.0]
	for index in range(expected_trigger_chances.size()):
		var level := index + 1
		_expect_close(
			PerkConversionValues.get_value("rainbow_fur_glove", "rainbow_glove_trigger_chance_pct", level),
			expected_trigger_chances[index],
			"rainbow trigger chance Lv%d" % level
		)
		_expect_close(
			PerkConversionValues.get_value("rainbow_fur_glove", "rainbow_glove_cooldown_reduction_pct", level),
			expected_cooldown_reductions[index],
			"rainbow cooldown reduction Lv%d" % level
		)
	_expect_close(
		PerkConversionValues.get_value("rainbow_fur_glove", "rainbow_glove_cooldown_reduction_pct", 6),
		23.0,
		"rainbow cooldown reduction Lv6 should continue the authored +3%p slope"
	)


func _verify_on_flag_uses_perk_levels() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in VALUE_CASES:
		var case_data: Dictionary = case_value
		for level in [1, 5]:
			var runtime: Object = _make_runtime({str(case_data["id"]): level})
			_expect_close(
				_read_case_value(runtime, case_data),
				PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), level),
				"ON should use Lv%d perk value for %s.%s" % [level, str(case_data["id"]), str(case_data["key"])]
			)
	for level in [1, 5]:
		var soul_runtime: Object = _make_runtime({"soul_burst": level})
		_expect_close(
			soul_runtime.get_soul_burst_gauge_cost(),
			PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", level),
			"ON should use Lv%d Soul Burst cost" % level
		)
		var speed_runtime: Object = _make_runtime({"speedgear": level})
		_expect_close(speed_runtime.get_speedgear_turn_decel_multiplier(), 1.0, "ON retired Speedgear should ignore stale Lv%d" % level)
		_expect_close(_movement_speed_after_speedgear_config(speed_runtime), -2.5, "ON retired Speedgear should keep turn movement neutral at stale Lv%d" % level)
		var gravity_runtime: Object = _make_runtime({"gravitybelt": level})
		_expect_close(_movement_speed_after_gravity_config(gravity_runtime), 6.0, "ON should use Gravity Belt perk-only movement at Lv%d" % level)
	var bonus_runtime: Object = _make_runtime({"shrapnel_armor": 3}, 2)
	_expect(bonus_runtime.get_converted_perk_effect_level("shrapnel_armor") == 5, "Batch3a bridge should expose base+bonus effective level")
	_expect_close(bonus_runtime.get_shrapnel_armor_gauge_cost(), 25.0, "base 3 + bonus 2 should use Shrapnel Armor Lv5 cost")


func _verify_on_flag_level_zero_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var runtime: Object = _make_runtime({})
	for case_value in VALUE_CASES:
		var case_data: Dictionary = case_value
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON level 0 should be inactive for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	_expect_close(runtime.get_soul_burst_gauge_cost(), 160.0, "ON level 0 Soul Burst should match unequipped default cost")
	_expect(not runtime.can_soul_burst_dash(500.0), "ON level 0 Soul Burst boolean gate should be inactive")
	_expect_close(runtime.get_speedgear_turn_decel_multiplier(), 1.0, "ON level 0 Speedgear should be neutral")
	_expect_close(_movement_speed_after_gravity_config(runtime), 0.5, "ON level 0 Gravity Belt should not produce instant movement")
	_expect_close(_movement_speed_after_speedgear_config(runtime), -2.5, "ON level 0 Speedgear should not alter turn movement")


func _verify_on_flag_item_only_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_item(runtime, str(case_data["id"]), {str(case_data["key"]): 500.0}), "ON item-only fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON item-only should not leak item roll for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var soul_runtime: Object = _make_runtime({})
	_expect(_equip_item(soul_runtime, "soul_burst", {"soul_burst_gauge_cost": 110.0}), "ON item-only Soul Burst should equip")
	_expect_close(soul_runtime.get_soul_burst_gauge_cost(), 160.0, "ON item-only Soul Burst should not leak item cost")
	_expect(not soul_runtime.can_soul_burst_dash(500.0), "ON item-only Soul Burst gate should be inactive")
	var gravity_runtime: Object = _make_runtime({})
	_expect(_equip_item(gravity_runtime, "gravitybelt", {}), "ON item-only Gravity Belt should equip")
	_expect(not gravity_runtime.is_gravitybelt_effect_active(), "ON item-only Gravity Belt effect gate should be inactive")
	_expect_close(_movement_speed_after_gravity_config(gravity_runtime), 0.5, "ON item-only Gravity Belt should not alter movement")
	var speed_runtime: Object = _make_runtime({})
	_expect(_equip_item(speed_runtime, "speedgear", {}), "ON item-only Speedgear should equip")
	_expect(not speed_runtime.is_speedgear_effect_active(), "ON item-only Speedgear effect gate should be inactive")
	_expect_close(speed_runtime.get_speedgear_turn_decel_multiplier(), 1.0, "ON item-only Speedgear should be neutral")
	_expect_close(_movement_speed_after_speedgear_config(speed_runtime), -2.5, "ON item-only Speedgear should not alter movement")


func _verify_on_flag_perk_replaces_item_without_max() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({str(case_data["id"]): 1})
		_expect(_equip_item(runtime, str(case_data["id"]), {str(case_data["key"]): 500.0}), "ON replacement fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), 1),
			"ON should replace item roll instead of max/add for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var soul_runtime: Object = _make_runtime({"soul_burst": 1})
	_expect(_equip_item(soul_runtime, "soul_burst", {"soul_burst_gauge_cost": 110.0}), "ON replacement Soul Burst should equip")
	_expect_close(soul_runtime.get_soul_burst_gauge_cost(), 170.0, "ON Soul Burst should use Lv1 perk cost, not lower item cost")
	_expect(not soul_runtime.can_soul_burst_dash(169.0), "ON Soul Burst Lv1 should require the perk cost")
	_expect(soul_runtime.can_soul_burst_dash(170.0), "ON Soul Burst Lv1 should activate at the perk cost")


func _verify_boolean_effect_gates() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	for item_id in [
		"adversity_armor",
		"shrapnel_armor",
		"soul_burst",
		"rainbow_fur_glove",
		"venom_mist_gauntlet",
		"gravitybelt",
		"speedgear",
	]:
		var off_runtime: Object = _make_runtime({})
		_expect(_equip_item(off_runtime, item_id, {}), "OFF boolean fixture should equip %s" % item_id)
		_expect(_read_effect_gate(off_runtime, item_id), "OFF %s effect gate should follow equipped state" % item_id)

	PerkConversionFlags.debug_set_enabled(true)
	var on_runtime: Object = _make_runtime({
		"adversity_armor": 1,
		"shrapnel_armor": 1,
		"soul_burst": 1,
		"rainbow_fur_glove": 1,
		"venom_mist_gauntlet": 1,
		"gravitybelt": 1,
		"speedgear": 1,
	})
	_expect(on_runtime.is_adversity_armor_effect_active(), "ON perk-only Adversity effect gate should be active")
	_expect(on_runtime.is_shrapnel_armor_effect_active(), "ON perk-only Shrapnel effect gate should be active")
	_expect(on_runtime.is_soul_burst_effect_active(), "ON perk-only Soul Burst effect gate should be active")
	_expect(on_runtime.is_rainbow_fur_glove_effect_active(), "ON perk-only Rainbow effect gate should be active")
	_expect(on_runtime.is_venom_mist_gauntlet_effect_active(), "ON perk-only Venom Mist effect gate should be active")
	_expect(on_runtime.is_gravitybelt_effect_active(), "ON perk-only Gravity Belt effect gate should be active")
	_expect(not on_runtime.is_speedgear_effect_active(), "ON retired Speedgear effect gate should ignore stale perk levels")


func _verify_runtime_consumers_use_batch3a_getters() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_adversity_runtime_consumer()
	_verify_shrapnel_runtime_consumer()
	_verify_soul_burst_runtime_consumer()
	_verify_rainbow_runtime_consumer()
	_verify_venom_runtime_consumer()


func _verify_adversity_runtime_consumer() -> void:
	var runtime: Object = _make_runtime({"adversity_armor": 5})
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref, audio)
	seed(31)
	var queued := false
	for _i in range(120):
		if runtime.try_queue_adversity_armor_after_loss({"owner": owner, "registry": registry}):
			queued = true
			break
	_expect(queued, "ON Adversity perk should be able to queue without the old item equipped gate")
	_expect(runtime.adversity_armor_pending_invincible, "ON Adversity proc should mark pending invincibility")
	runtime.runtime_perk_state_ref.runtime_skill_levels["adversity_armor"] = 1
	runtime.on_round_start(owner, registry)
	_expect(runtime.is_adversity_armor_invincible(), "ON Adversity round start should activate the shield")
	_expect_close(runtime.adversity_armor_invincible_timer_frames, 300.0, "ON Adversity should preserve round-start requery timing for duration")
	_expect_close(runtime.consume_adversity_armor_serve_speed_bonus(), 0.2, "ON Adversity should preserve fixed serve-speed side effect")
	_expect(audio.active_item_calls >= 1, "ON Adversity activation should keep routed audio")


func _verify_shrapnel_runtime_consumer() -> void:
	var runtime: Object = _make_runtime({"shrapnel_armor": 5})
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref, audio, feedback)
	seed(77)
	var result: Dictionary = {}
	for _i in range(200):
		owner.special_gauge = 100.0
		result = runtime.try_proc_shrapnel_armor_player_hit(
			Vector2(360.0, 650.0),
			{"special_gauge": owner.special_gauge, "player_pos": owner.player_pos, "player_paddle_width": owner.player_paddle_width},
			{"owner": owner, "registry": registry, "feedback": feedback}
		)
		if bool(result.get("activated", false)):
			break
	_expect(bool(result.get("activated", false)), "ON Shrapnel perk should proc through the player-hit consumer without the item")
	_expect_close(float(result.get("gauge_cost", 0.0)), 25.0, "ON Shrapnel Lv5 should feed perk gauge cost into proc result")
	_expect(int(result.get("shard_count", 0)) == 8, "ON Shrapnel Lv5 should feed shard count into burst")
	_expect(int(result.get("knockback_level", 0)) == 4, "ON Shrapnel Lv5 should feed knockback level into proc result")
	_expect_close(owner.special_gauge, 75.0, "ON Shrapnel proc should spend the perk cost")
	_expect(runtime.shrapnel_armor_shards.size() == 8, "ON Shrapnel proc should spawn the perk shard count")
	_expect(audio.shrapnel_fire_calls == 1, "ON Shrapnel proc should keep routed fire audio")
	_expect(feedback.gauge_flash_calls == 1, "ON Shrapnel proc should keep gauge feedback")


func _verify_soul_burst_runtime_consumer() -> void:
	var runtime: Object = _make_runtime({"soul_burst": 5})
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref, audio)
	var result: Dictionary = runtime.try_consume_soul_burst_dash(
		150.0,
		Vector2(360.0, 690.0),
		1.0,
		registry
	)
	_expect(bool(result.get("activated", false)), "ON Soul Burst perk should activate without the old item equipped gate")
	_expect_close(float(result.get("gauge_cost", 0.0)), 100.0, "ON Soul Burst Lv5 should feed perk gauge cost into consume result")
	_expect_close(float(result.get("special_gauge", 0.0)), 50.0, "ON Soul Burst should spend the perk gauge cost")
	_expect(audio.soul_burst_calls == 1, "ON Soul Burst consume should keep routed audio")


func _verify_rainbow_runtime_consumer() -> void:
	var runtime: Object = _make_runtime({"rainbow_fur_glove": 5})
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var skill_state := FakeSkillState.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref, audio, feedback)
	seed(109)
	var result: Dictionary = {}
	for _i in range(240):
		result = runtime.try_proc_rainbow_fur_glove_player_hit(
			Vector2(360.0, 650.0),
			{"current_time_msec": 4000, "player_pos": owner.player_pos, "player_paddle_width": owner.player_paddle_width},
			{"owner": owner, "registry": registry, "feedback": feedback, "skill_state": skill_state}
		)
		if bool(result.get("activated", false)):
			break
	_expect(bool(result.get("activated", false)), "ON Rainbow perk should proc through the player-hit consumer without the item")
	_expect_close(float(result.get("cooldown_reduction_pct", 0.0)), 20.0, "ON Rainbow Lv5 should feed perk cooldown reduction")
	_expect_close(skill_state.last_fraction, 0.20, "ON Rainbow consumer should apply the perk cooldown fraction")
	_expect(skill_state.reduction_calls == 1, "ON Rainbow consumer should call the cooldown reducer once")
	_expect(audio.rainbow_calls == 1, "ON Rainbow proc should keep routed audio")
	_expect(feedback.shake_calls == 1, "ON Rainbow proc should keep feedback")


func _verify_venom_runtime_consumer() -> void:
	var runtime: Object = _make_runtime({"venom_mist_gauntlet": 5})
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref, FakeAudio.new())
	_expect(runtime.try_spawn_venom_mist_at_boss(Vector2(380.0, 95.0), {"owner": owner, "registry": registry}, true), "ON Venom perk should spawn forced mist without the old item equipped gate")
	_expect(runtime.is_venom_mist_field_active(), "ON Venom forced spawn should activate the mist field")
	_expect_close(runtime.venom_mist_duration_frames, 330.0, "ON Venom Lv5 should feed duration into field runtime")


func _verify_venom_guard_structure() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var spawn_pool := ActiveItemFieldSpawnPool.new()
	var runtime: Object = _make_runtime({"venom_mist_gauntlet": 1})
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref)
	var smasher_owner := FakeOwner.new()
	smasher_owner.selected_character_type = "smasher"
	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	_expect(not spawn_pool.get_field_spawn_candidate_names(registry, smasher_owner).has("venom_mist_gauntlet"), "flag-OFF existing Venom guard should exclude non-Viper field offers")
	_expect(spawn_pool.get_field_spawn_candidate_names(registry, viper_owner).has("venom_mist_gauntlet"), "flag-OFF existing Venom guard should allow Viper field offers")
	PerkConversionFlags.debug_set_enabled(true)
	_expect(runtime.try_spawn_venom_mist_at_boss(Vector2(380.0, 95.0), {"owner": smasher_owner, "registry": registry}, true), "existing Venom runtime has no character guard beyond offer restrictions")


func _verify_overflow_saturates_at_consumer_limits() -> void:
	# 무지개 털장갑 쿨감 오버플로우가 소비자 0.95 클램프와 정합하게 95에
	# 포화한다(OVERFLOW_VALUE_BOUNDS↔공개 소비 함수 관통 씰).
	PerkConversionFlags.debug_set_enabled(true)
	# Lv.98: 새 하향 곡선의 trigger 외삽(7+1/lv)이 100 캡에 도달해
	# proc이 결정론이 된다(Lv.60은 62%라 randf 게이트가 비결정론).
	var runtime: Object = _make_runtime({"rainbow_fur_glove": 98})
	_expect_close(runtime.get_rainbow_fur_glove_cooldown_reduction_pct(), 95.0, "overflow rainbow cooldown reduction must saturate at the consumer 0.95 clamp")
	_expect_close(runtime.get_rainbow_fur_glove_trigger_chance_pct(), 100.0, "overflow rainbow trigger must cap at 100 for the deterministic proc leg")
	# 최종 소비 관통: 실제 적용 fraction이 정확히 0.95에 클램프됨을 봉인
	# (소비 clamp가 0.90으로 드리프트해도 게터 씰만으로는 GREEN인 구멍 차단).
	var proc_result: Dictionary = runtime.try_proc_rainbow_fur_glove_player_hit(Vector2(380.0, 600.0))
	_expect(bool(proc_result.get("activated", false)), "overflow rainbow (trigger capped at 100) must proc deterministically")
	_expect_close(float(proc_result.get("cooldown_reduction_fraction", 0.0)), 0.95, "overflow rainbow proc must apply exactly the 0.95 clamped fraction")


func _make_runtime(levels: Dictionary, bonus: int = 0) -> Object:
	var runtime: Object = MythicItemRuntime.new()
	var state: Object = RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	state.set_item_perk_level_bonus(bonus)
	runtime.get_snapshot()
	var registry := FakeRegistry.new(runtime, state)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return runtime


func _equip_item(runtime: Object, item_id: String, rolls: Dictionary) -> bool:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref)
	return bool(runtime.equip_item(item_id, owner, registry, rolls, false))


func _read_case_value(runtime: Object, case_data: Dictionary) -> float:
	return float(runtime.call(str(case_data["getter"])))


func _read_effect_gate(runtime: Object, item_id: String) -> bool:
	match item_id:
		"adversity_armor":
			return runtime.is_adversity_armor_effect_active()
		"shrapnel_armor":
			return runtime.is_shrapnel_armor_effect_active()
		"soul_burst":
			return runtime.is_soul_burst_effect_active()
		"rainbow_fur_glove":
			return runtime.is_rainbow_fur_glove_effect_active()
		"venom_mist_gauntlet":
			return runtime.is_venom_mist_gauntlet_effect_active()
		"gravitybelt":
			return runtime.is_gravitybelt_effect_active()
		"speedgear":
			return runtime.is_speedgear_effect_active()
	return false


func _movement_speed_after_gravity_config(runtime: Object) -> float:
	var config := _base_movement_config()
	runtime.apply_player_movement_config(config)
	var movement: Object = PlayerMovementState.new()
	var result: Dictionary = movement.update_horizontal(
		1.0 / 60.0,
		Vector2(300.0, 690.0),
		0.0,
		1.0,
		0.0,
		760.0,
		155.0,
		config
	)
	return float(result.get("player_speed", 0.0))


func _movement_speed_after_speedgear_config(runtime: Object) -> float:
	var config := _base_movement_config()
	config["paddle_turn_decel"] = float(config["paddle_turn_decel"]) * runtime.get_player_turn_decel_multiplier()
	var movement: Object = PlayerMovementState.new()
	var result: Dictionary = movement.update_horizontal(
		1.0 / 60.0,
		Vector2(300.0, 690.0),
		-4.0,
		1.0,
		0.0,
		760.0,
		155.0,
		config
	)
	return float(result.get("player_speed", 0.0))


func _base_movement_config() -> Dictionary:
	return {
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_decel": 0.5,
		"paddle_turn_decel": 1.0,
		"paddle_width": 155.0,
	}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
