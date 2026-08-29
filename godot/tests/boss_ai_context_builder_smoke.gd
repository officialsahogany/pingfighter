extends SceneTree

const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BattleUpdateActorContext := preload("res://scripts/core/battle_update_actor_context.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 2
	var ai_mode := "champion"
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := "cheongringwi"
	var ball_active := true
	var player_pos := Vector2(200.0, 690.0)
	var ball_pos := Vector2(320.0, 410.0)
	var ball_vel := Vector2(7.0, -3.0)
	var ball_impact_boost := 1.25
	var ball_boost_decay_rate := 0.97
	var ball_min_boost := 0.65
	var selected_character_type := "viper"


class FakeRoundState:
	extends RefCounted

	func is_waiting_for_serve() -> bool:
		return false

	func does_player_serve() -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": 0.45,
			"serve_delay": 2.25,
		}


class FakePowerState:
	extends RefCounted

	func is_parabola_active() -> bool:
		return true

	func get_combo_consumed() -> int:
		return 2


class FakeWhipState:
	extends RefCounted

	func get_ai_context() -> Dictionary:
		return {"whip_marker": true}


class FakeBossContextSource:
	extends RefCounted

	var marker: String

	func _init(next_marker: String) -> void:
		marker = next_marker

	func get_boss_ai_context() -> Dictionary:
		return {marker: true}


class FakeStage2SkillState:
	extends RefCounted

	var expected_background: Object

	func _init(background: Object) -> void:
		expected_background = background

	func get_boss_ai_context(stage_background: Object = null) -> Dictionary:
		return {
			"stage2_skill_marker": true,
			"stage2_background_ok": stage_background == expected_background,
		}


class FakeStageBackground:
	extends RefCounted

	func get_boss_ai_context() -> Dictionary:
		return {"stage_background_marker": true}


class FakeMonkeyEvent:
	extends RefCounted

	func get_boss_ai_context() -> Dictionary:
		return {"monkey_banana_marker": true}


class FakeStage5HongryunState:
	extends RefCounted

	func get_boss_ai_context() -> Dictionary:
		return {"stage5_hongryun_marker": true}


class FakeStageRouter:
	extends RefCounted

	func get_instance(registry: Object, current_stage: int, role: String) -> Object:
		if current_stage == 2 and role == "stage_background":
			return registry.get_instance("stage2_pillar_background")
		return null


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func _init() -> void:
		instances["round_flow_state"] = FakeRoundState.new()
		instances["smasher_power_smash_state"] = FakePowerState.new()
		instances["stage1_dalji_whip_skill_state"] = FakeWhipState.new()
		instances["active_item_runtime"] = FakeBossContextSource.new("active_item_marker")
		instances["mythic_item_runtime"] = FakeBossContextSource.new("mythic_item_marker")
		instances["smasher_plasma_state"] = FakeBossContextSource.new("plasma_marker")
		instances["viper_skill_runtime"] = FakeBossContextSource.new("viper_marker")
		instances["stage2_pillar_background"] = FakeStageBackground.new()
		instances["stage2_boss_skill_state"] = FakeStage2SkillState.new(instances["stage2_pillar_background"])
		instances["stage2_monkey_banana_event"] = FakeMonkeyEvent.new()
		instances["stage5_hongryun_state"] = FakeStage5HongryunState.new()
		instances["stage_runtime_router"] = FakeStageRouter.new()
		instances["game_audio"] = RefCounted.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var builder: Object = BossAiContextBuilder.new()

	var context: Dictionary = builder.build_context(owner, registry)
	_verify_context(context, "direct builder")
	_expect(context.get("audio", null) == registry.instances["game_audio"], "direct builder should include audio dependency")
	_expect(not registry.requested_keys.has("smasher_power_smash_state"), "Viper boss context should not request Smasher power state")
	_expect(not registry.requested_keys.has("smasher_plasma_state"), "Viper boss context should not request Smasher plasma state")
	_expect(not registry.requested_keys.has("stage1_dalji_whip_skill_state"), "Stage 2 boss context should not request Stage 1 whip state")

	registry.requested_keys.clear()
	var facade_context: Dictionary = BattleUpdateActorContext.new().build_boss_ai_context(owner, registry)
	_verify_context(facade_context, "actor context facade")
	_verify_variant_movement_parity(builder, owner, registry)

	registry.instances.erase("stage2_boss_skill_state")
	var stage_fallback_context: Dictionary = builder.build_context(owner, registry)
	_expect(bool(stage_fallback_context.get("stage_background_marker", false)), "Stage 2 boss context should fall back to background AI context")

	owner.selected_character_type = "smasher"
	var smasher_context: Dictionary = builder.build_context(owner, registry)
	_expect(not bool(smasher_context.get("viper_marker", false)), "Smasher boss context should skip Viper runtime context")
	_expect(bool(smasher_context.get("power_smashing_parabola_active", false)), "Smasher boss context should include power smash state")
	_expect(int(smasher_context.get("power_smashing_combo_consumed", 0)) == 2, "Smasher boss context should include power combo count")
	_expect(bool(smasher_context.get("plasma_marker", false)), "Smasher boss context should merge plasma AI context")
	_expect(not bool(smasher_context.get("whip_marker", false)), "Stage 2 Smasher boss context should skip Stage 1 whip state")

	owner.current_stage = 1
	var stage1_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(stage1_context.get("boss_mistake_chance", 0.0)) - 0.10) <= 0.001, "Stage 1 Dalji boss mistake chance should be 10%")
	_expect(bool(stage1_context.get("whip_marker", false)), "Stage 1 boss context should merge Dalji whip AI context")

	owner.ai_mode = "junior"
	var junior_stage1_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(junior_stage1_context.get("boss_mistake_chance", 0.0)) - 0.20) <= 0.001, "Junior Stage 1 Dalji boss mistake chance should be 20%")
	owner.ai_mode = "mythic league"
	var mythic_stage1_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(mythic_stage1_context.get("boss_mistake_chance", 0.0)) - 0.05) <= 0.001, "Mythic Stage 1 boss mistake chance should be 5%")
	owner.current_stage = 2
	var mythic_stage2_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(mythic_stage2_context.get("boss_mistake_chance", 0.0)) - 0.045) <= 0.001, "Mythic Stage 2 boss mistake chance should be 4.5%")
	owner.ai_mode = "junior"
	var junior_stage2_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(junior_stage2_context.get("boss_mistake_chance", 0.0)) - 0.14) <= 0.001, "Junior Stage 2 boss mistake chance should be 14%")
	owner.ai_mode = "champion"

	owner.current_stage = 3
	var stage3_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(stage3_context.get("boss_mistake_chance", 0.0)) - 0.08) <= 0.001, "Stage 3 Menhera Girl boss mistake chance should be 8%")
	_expect(not bool(stage3_context.get("whip_marker", false)), "Stage 3 boss context should skip Stage 1 whip state")
	_expect(abs(float(stage3_context.get("boss_stage_speed_multiplier", 0.0)) - 1.06) <= 0.001, "Stage 3 boss speed should be +6% over Stage 1")
	_expect(abs(float(stage3_context.get("boss_movement_max_speed", 0.0)) - 6.3175 * 1.5 * 1.06) <= 0.001, "Stage 3 actual boss max speed should use the +3% per-stage ramp")
	_expect(int(stage3_context.get("boss_dash_max_tokens", 0)) == 1, "Champion boss should keep one base dash token")
	_expect(not bool(stage3_context.get("boss_dash_chain_enabled", true)), "Champion boss should not enable chained boss dash")
	_expect(abs(float(stage3_context.get("boss_dash_trigger_chance", 0.0)) - 0.30) <= 0.001, "Champion boss dash trigger chance should stay at 30%")
	_expect(abs(float(stage3_context.get("boss_dash_chain_trigger_chance", 0.0)) - 0.30) <= 0.001, "Champion boss dash chain chance should be explicit")
	_expect(abs(float(stage3_context.get("boss_dash_stage_distance_multiplier", 0.0)) - 1.10) <= 0.001, "Stage 3 boss dash distance should be +10% over Stage 1")
	_expect(abs(float(stage3_context.get("boss_dash_stage_cooldown_multiplier", 0.0)) - 0.90) <= 0.001, "Stage 3 boss dash cooldown should be -10% from Stage 1")
	_expect(abs(float(stage3_context.get("boss_dash_max_distance", 0.0)) - 316.8 * 1.10) <= 0.001, "Stage 3 boss dash distance should use the +5% per-stage ramp")
	_expect(abs(float(stage3_context.get("boss_dash_cooldown_min_seconds", 0.0)) - 40.0 * 0.90) <= 0.001, "Stage 3 boss dash min cooldown should use the -5% per-stage ramp")
	_expect(abs(float(stage3_context.get("boss_dash_cooldown_max_seconds", 0.0)) - 55.0 * 0.90) <= 0.001, "Stage 3 boss dash max cooldown should use the -5% per-stage ramp")

	owner.ai_mode = "mythic league"
	var mythic_ball_speed_ratio: float = 32.0 / 26.0
	var mythic_stage3_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(mythic_stage3_context.get("boss_league_movement_multiplier", 0.0)) - mythic_ball_speed_ratio) <= 0.001, "Mythic boss movement should match the 32/26 ball speed cap ratio")
	_expect(abs(float(mythic_stage3_context.get("boss_max_speed", 0.0)) - 6.3175 * 1.06 * mythic_ball_speed_ratio) <= 0.001, "Mythic boss base max speed should match the ball speed cap ratio")
	_expect(abs(float(mythic_stage3_context.get("boss_movement_accel", 0.0)) - 0.798 * 1.5 * 1.06 * mythic_ball_speed_ratio) <= 0.001, "Mythic boss acceleration should match the ball speed cap ratio")
	_expect(abs(float(mythic_stage3_context.get("boss_movement_decel", 0.0)) - 0.798 * 1.5 * 1.06 * mythic_ball_speed_ratio) <= 0.001, "Mythic boss deceleration should match the ball speed cap ratio")
	_expect(abs(float(mythic_stage3_context.get("boss_movement_max_speed", 0.0)) - 6.3175 * 1.5 * 1.06 * mythic_ball_speed_ratio) <= 0.001, "Mythic boss actual max speed should match the ball speed cap ratio")
	_expect(abs(float(mythic_stage3_context.get("boss_paddle_width", 0.0)) - 115.0) <= 0.001, "Mythic boss hitbox width should be 15% wider")
	_expect(abs(float(mythic_stage3_context.get("boss_mistake_chance", 0.0)) - 0.04) <= 0.001, "Mythic Stage 3 boss mistake chance should be 4%")
	_expect(abs(float(mythic_stage3_context.get("boss_mistake_error_min", -1.0)) - 0.0) <= 0.001, "Mythic boss mistake error minimum should allow small misses")
	_expect(abs(float(mythic_stage3_context.get("boss_mistake_error_max", 0.0)) - 20.0) <= 0.001, "Mythic boss mistake error maximum should stay within 20px")
	_expect(int(mythic_stage3_context.get("boss_dash_max_tokens", 0)) == 2, "Mythic boss should start from two base dash tokens")
	_expect(bool(mythic_stage3_context.get("boss_dash_chain_enabled", false)), "Mythic boss should explicitly enable chained boss dash")
	_expect(abs(float(mythic_stage3_context.get("boss_dash_trigger_chance", 0.0)) - 1.0) <= 0.001, "Mythic emergency boss dash should trigger whenever the dash gate says it is needed")
	_expect(abs(float(mythic_stage3_context.get("boss_dash_chain_trigger_chance", 0.0)) - 1.0) <= 0.001, "Mythic chained boss dash should match the emergency dash trigger chance")

	owner.ai_mode = "junior league"
	var junior_stage3_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(junior_stage3_context.get("boss_mistake_chance", 0.0)) - 0.13) <= 0.001, "Junior Stage 3 boss mistake chance should be 13%")
	_expect(abs(float(junior_stage3_context.get("boss_stage_speed_multiplier", 0.0)) - 1.06) <= 0.001, "Junior Stage 3 boss stage speed multiplier should remain stage-only")
	_expect(abs(float(junior_stage3_context.get("boss_league_movement_multiplier", 0.0)) - 0.90) <= 0.001, "Junior boss movement should expose the -10% league multiplier")
	_expect(abs(float(junior_stage3_context.get("boss_max_speed", 0.0)) - 6.3175 * 1.06 * 0.90) <= 0.001, "Junior boss base max speed should be 10% slower")
	_expect(abs(float(junior_stage3_context.get("boss_movement_accel", 0.0)) - 0.798 * 1.5 * 1.06 * 0.90) <= 0.001, "Junior boss acceleration should be 10% slower")
	_expect(abs(float(junior_stage3_context.get("boss_movement_decel", 0.0)) - 0.798 * 1.5 * 1.06 * 0.90) <= 0.001, "Junior boss deceleration should be 10% slower")
	_expect(abs(float(junior_stage3_context.get("boss_movement_max_speed", 0.0)) - 6.3175 * 1.5 * 1.06 * 0.90) <= 0.001, "Junior boss actual max speed should be 10% slower")
	_expect(int(junior_stage3_context.get("boss_dash_max_tokens", 0)) == 1, "Junior boss should keep one base dash token")
	_expect(not bool(junior_stage3_context.get("boss_dash_chain_enabled", true)), "Junior boss should not enable chained boss dash")
	owner.ai_mode = "champion"

	owner.current_stage = 4
	var stage4_context: Dictionary = builder.build_context(owner, registry)
	_expect(abs(float(stage4_context.get("boss_mistake_chance", 0.0)) - 0.07) <= 0.001, "Stage 4 Ponk boss mistake chance should be 7%")

	owner.current_stage = 5
	var stage5_context: Dictionary = builder.build_context(owner, registry)
	_expect(bool(stage5_context.get("stage5_hongryun_marker", false)), "Stage 5 boss context should merge Hongryun state context")
	_expect(not bool(stage5_context.get("stage2_skill_marker", false)), "Stage 5 boss context should skip Stage 2 skill context")
	_expect(int(stage5_context.get("boss_dash_max_tokens", 0)) == 1, "Champion Stage 5 boss should keep one dash token")
	_expect(not bool(stage5_context.get("boss_dash_chain_enabled", true)), "Champion Stage 5 boss should not enable chained boss dash")
	owner.ai_mode = "mythic league"
	var mythic_stage5_context: Dictionary = builder.build_context(owner, registry)
	_expect(int(mythic_stage5_context.get("boss_dash_max_tokens", 0)) == 3, "Mythic Stage 5 boss should start from three dash tokens")
	_expect(bool(mythic_stage5_context.get("boss_dash_chain_enabled", false)), "Mythic Stage 5 boss should explicitly enable chained boss dash")
	_expect(abs(float(mythic_stage5_context.get("boss_mistake_chance", 0.0)) - 0.03) <= 0.001, "Mythic Stage 5 boss mistake chance should be 3%")
	_expect(abs(float(mythic_stage5_context.get("boss_dash_trigger_chance", 0.0)) - 1.0) <= 0.001, "Mythic Stage 5 emergency boss dash should always trigger when gated")

	if _failures.is_empty():
		print("boss_ai_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_variant_movement_parity(builder: Object, owner: FakeOwner, registry: FakeRegistry) -> void:
	# AR-3 source parity seal — config/stage_configs.py:162-225 (legacy authority).
	# | stage | original variants                  | accel/decel/max | instant_stop | Godot route |
	# | 1     | Dalji/Gaksi/Podo                   | 1.00            | 1.00         | catalogued  |
	# | 2     | Cheongringwi/Molewang              | 1.00            | 1.00         | catalogued  |
	# | 2     | Arachne                            | 0.70            | 0.70         | catalogued  |
	# | 3     | Yeonmyo/Teddy Bear/Alice           | 1.00            | 1.00         | catalogued  |
	# | 4     | Ponk                               | 1.00            | 1.00         | base only   |
	# | 4     | Inwang                             | 0.80            | 1.20         | not ported  |
	# GRT-053 call path: this builder emits boss_movement_accel/decel/max_speed,
	# BossAiState.update passes them to BossAiTurnInertiaResolver.update_velocity,
	# and the returned velocity is integrated into boss_pos. boss_max_speed is the
	# sibling key consumed by dash reach and speed-defense initial-velocity gates.
	var unchanged_variants := [
		[1, "dalji"],
		[1, "gaksi"],
		[1, "podo"],
		[2, "cheongringwi"],
		[2, "molewang"],
		[3, "yeonmyo"],
		[3, "teddy_bear"],
		[3, "alice"],
	]
	for variant_case in unchanged_variants:
		var stage_id: int = int(variant_case[0])
		var variant_id: String = str(variant_case[1])
		var entry: Dictionary = StageBossVariantCatalog.get_entry(stage_id, variant_id)
		_expect(
			is_equal_approx(float(entry.get("boss_movement_scale", 1.0)), 1.0),
			"%s should keep the original 1.0 boss movement scale" % variant_id
		)

	owner.current_stage = 2
	owner.ai_mode = "champion"
	owner.stage_boss_variant = "cheongringwi"
	var default_context: Dictionary = builder.build_context(owner, registry)
	owner.stage_boss_variant = "arachne"
	var arachne_context: Dictionary = builder.build_context(owner, registry)

	var arachne_entry: Dictionary = StageBossVariantCatalog.get_entry(2, "arachne")
	_expect(
		is_equal_approx(float(arachne_entry.get("boss_movement_scale", 1.0)), 0.70),
		"Arachne catalog entry should restore the original 0.70 movement scale"
	)
	for movement_key in ["boss_movement_accel", "boss_movement_decel", "boss_movement_max_speed"]:
		_expect(
			is_equal_approx(
				float(arachne_context.get(movement_key, 0.0)),
				float(default_context.get(movement_key, 0.0)) * 0.70
			),
			"Arachne %s should be 0.70x the default Stage 2 profile" % movement_key
		)
	_expect(
		is_equal_approx(
			float(arachne_context.get("boss_max_speed", 0.0)),
			float(default_context.get("boss_max_speed", 0.0)) * 0.70
		),
		"Arachne boss_max_speed compatibility key should use the same 0.70 scale"
	)

	var default_step_context := default_context.duplicate(true)
	var arachne_step_context := arachne_context.duplicate(true)
	for movement_context in [default_step_context, arachne_step_context]:
		movement_context["boss_dash_enabled"] = false
		movement_context["boss_mistake_chance"] = 0.0
		movement_context["ball_active"] = false
		movement_context["waiting_for_serve"] = false
		movement_context["player_serves"] = true
	var boss_pos := Vector2(100.0, 25.0)
	var default_step: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 0.0, default_step_context)
	var arachne_step: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 0.0, arachne_step_context)
	var default_step_velocity: float = float(default_step.get("boss_vel", 0.0))
	var arachne_step_velocity: float = float(arachne_step.get("boss_vel", 0.0))
	_expect(default_step_velocity > 0.0, "default Stage 2 production movement step should advance")
	_expect(
		is_equal_approx(arachne_step_velocity, default_step_velocity * 0.70),
		"Arachne production movement step should consume the 0.70-scaled profile"
	)

	owner.current_stage = 2
	owner.ai_mode = "champion"
	owner.stage1_boss_variant = "dalji"
	owner.stage_boss_variant = "cheongringwi"


func _verify_context(context: Dictionary, source: String) -> void:
	_expect(int(context.get("current_stage", 0)) == 2, "%s should keep current stage" % source)
	_expect(str(context.get("ai_mode", "")) == "champion", "%s should copy AI mode" % source)
	_expect(not bool(context.get("waiting_for_serve", true)), "%s should read round wait state" % source)
	_expect(bool(context.get("player_serves", false)), "%s should read serving side" % source)
	_expect(abs(float(context.get("boss_serve_timer", 0.0)) - 0.45) <= 0.001, "%s should expose serve wait timer to boss AI" % source)
	_expect(abs(float(context.get("boss_serve_target_delay", 0.0)) - 2.25) <= 0.001, "%s should expose serve target delay to boss AI" % source)
	_expect(context.get("player_pos", Vector2.ZERO) == Vector2(200.0, 690.0), "%s should copy player position" % source)
	_expect(context.get("ball_pos", Vector2.ZERO) == Vector2(320.0, 410.0), "%s should copy ball position" % source)
	_expect(context.get("ball_vel", Vector2.ZERO) == Vector2(7.0, -3.0), "%s should copy ball velocity" % source)
	_expect(abs(float(context.get("ball_impact_boost", 0.0)) - 1.25) <= 0.001, "%s should copy impact boost" % source)
	_expect(abs(float(context.get("ball_boost_decay_rate", 0.0)) - 0.97) <= 0.001, "%s should copy boost decay" % source)
	_expect(abs(float(context.get("ball_min_boost", 0.0)) - 0.65) <= 0.001, "%s should copy min boost" % source)
	_expect(abs(float(context.get("boss_stage_speed_multiplier", 0.0)) - 1.03) <= 0.001, "%s should add +3%% boss speed on Stage 2" % source)
	_expect(abs(float(context.get("boss_league_movement_multiplier", 0.0)) - 1.0) <= 0.001, "%s should keep Champion boss movement at 100%%" % source)
	_expect(abs(float(context.get("boss_paddle_width", 0.0)) - 100.0) <= 0.001, "%s should keep Champion boss hitbox width at 100px" % source)
	_expect(abs(float(context.get("boss_max_speed", 0.0)) - 6.3175 * 1.03) <= 0.001, "%s should scale base boss max speed per stage" % source)
	_expect(abs(float(context.get("boss_movement_accel", 0.0)) - 0.798 * 1.5 * 1.03) <= 0.001, "%s should scale boss movement acceleration per stage" % source)
	_expect(abs(float(context.get("boss_movement_decel", 0.0)) - 0.798 * 1.5 * 1.03) <= 0.001, "%s should scale boss movement deceleration per stage" % source)
	_expect(abs(float(context.get("boss_movement_max_speed", 0.0)) - 6.3175 * 1.5 * 1.03) <= 0.001, "%s should scale actual boss max speed per stage" % source)
	_expect(int(context.get("boss_dash_max_tokens", 0)) == 1, "%s should keep Champion boss dash max tokens at one" % source)
	_expect(abs(float(context.get("boss_dash_stage_distance_multiplier", 0.0)) - 1.05) <= 0.001, "%s should add +5%% boss dash distance on Stage 2" % source)
	_expect(abs(float(context.get("boss_dash_stage_cooldown_multiplier", 0.0)) - 0.95) <= 0.001, "%s should reduce boss dash cooldown by 5%% on Stage 2" % source)
	_expect(abs(float(context.get("boss_dash_max_distance", 0.0)) - 316.8 * 1.05) <= 0.001, "%s should scale boss dash distance per stage" % source)
	_expect(abs(float(context.get("boss_dash_cooldown_min_seconds", 0.0)) - 40.0 * 0.95) <= 0.001, "%s should scale boss dash min cooldown per stage" % source)
	_expect(abs(float(context.get("boss_dash_cooldown_max_seconds", 0.0)) - 55.0 * 0.95) <= 0.001, "%s should scale boss dash max cooldown per stage" % source)
	_expect(abs(float(context.get("boss_mistake_chance", 0.0)) - 0.09) <= 0.001, "%s should set Stage 2 boss mistake chance to 9%%" % source)
	_expect(abs(float(context.get("boss_mistake_error_min", 0.0)) - 78.0) <= 0.001, "%s should expose the default boss mistake error minimum" % source)
	_expect(abs(float(context.get("boss_mistake_error_max", 0.0)) - 140.0) <= 0.001, "%s should expose the default boss mistake error maximum" % source)
	_expect(not bool(context.get("power_smashing_parabola_active", false)), "%s should skip Smasher power state for Viper" % source)
	_expect(int(context.get("power_smashing_combo_consumed", 0)) == 0, "%s should expose zero power combo count for Viper" % source)
	_expect(not bool(context.get("whip_marker", false)), "%s should skip Stage 1 whip AI context on Stage 2" % source)
	_expect(bool(context.get("active_item_marker", false)), "%s should merge active item AI context" % source)
	_expect(bool(context.get("mythic_item_marker", false)), "%s should merge mythic item AI context" % source)
	_expect(not bool(context.get("plasma_marker", false)), "%s should skip Smasher plasma AI context for Viper" % source)
	_expect(bool(context.get("stage2_skill_marker", false)), "%s should merge Stage 2 skill AI context" % source)
	_expect(bool(context.get("stage2_background_ok", false)), "%s should pass routed background to Stage 2 skill context" % source)
	_expect(bool(context.get("monkey_banana_marker", false)), "%s should merge Stage 2 monkey-banana AI context" % source)
	_expect(bool(context.get("viper_marker", false)), "%s should merge Viper runtime boss context" % source)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
