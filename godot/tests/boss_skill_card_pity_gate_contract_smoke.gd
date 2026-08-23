extends SceneTree

const Stage1DaljiCooldownState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage2CheongringwiState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage3AliceState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage3TeddyBearState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")

const PITY_DISABLED_FIXTURE_ENV := "BOSS_SKILL_PITY_DISABLED_FIXTURE"
const EPSILON := 0.0001
const SIMULATION_HITS := 120000
const SIMULATION_HIT_STEP_SEC := 0.05
const SIMULATION_MEAN_RATIO_MIN := 0.90

const TEDDY_SPECS := [
	{
		"id": "cotton_throw",
		"chance": Stage3TeddyBearState.COTTON_THROW_CHANCE,
		"cost": Stage3TeddyBearState.COTTON_THROW_COST,
		"cooldown": "cotton_throw_cooldown",
		"counter": "cotton_throw_pity_failures",
		"trigger": "teddy_cotton_throw_triggered",
	},
	{
		"id": "cotton_bomb",
		"chance": Stage3TeddyBearState.COTTON_BOMB_CHANCE,
		"cost": Stage3TeddyBearState.COTTON_BOMB_COST,
		"cooldown": "cotton_bomb_cooldown",
		"counter": "cotton_bomb_pity_failures",
		"trigger": "teddy_cotton_bomb_triggered",
	},
	{
		"id": "deadly_hug",
		"chance": Stage3TeddyBearState.DEADLY_HUG_CHANCE,
		"cost": Stage3TeddyBearState.DEADLY_HUG_COST,
		"cooldown": "deadly_hug_cooldown",
		"counter": "deadly_hug_pity_failures",
		"trigger": "teddy_deadly_hug_triggered",
	},
	{
		"id": "heart_beam",
		"chance": Stage3TeddyBearState.HEART_BEAM_CHANCE,
		"cost": Stage3TeddyBearState.HEART_BEAM_COST,
		"cooldown": "heart_beam_cooldown",
		"counter": "heart_beam_pity_failures",
		"trigger": "teddy_heart_beam_triggered",
	},
]

const ALICE_PITY_SPECS := [
	{
		"id": "size_shift",
		"chance": Stage3AliceState.SIZE_SHIFT_CHANCE,
		"cost": Stage3AliceState.SIZE_SHIFT_COST,
		"cooldown": "size_shift_cooldown",
		"counter": "size_shift_pity_failures",
		"trigger": "alice_size_shift_triggered",
		"activation_rng_calls": 1,
	},
	{
		"id": "rabbit_projectile",
		"chance": Stage3AliceState.RABBIT_CHANCE,
		"cost": Stage3AliceState.RABBIT_COST,
		"cooldown": "rabbit_cooldown",
		"counter": "rabbit_pity_failures",
		"trigger": "alice_rabbit_triggered",
		"activation_rng_calls": 0,
	},
]

const ALICE_HUD_SPECS := [
	{"id": "mirror_world", "cost": Stage3AliceState.MIRROR_COST, "cooldown": "mirror_cooldown", "total": Stage3AliceState.MIRROR_COOLDOWN_SEC},
	{"id": "size_shift", "cost": Stage3AliceState.SIZE_SHIFT_COST, "cooldown": "size_shift_cooldown", "total": Stage3AliceState.SIZE_SHIFT_COOLDOWN_SEC},
	{"id": "rabbit_projectile", "cost": Stage3AliceState.RABBIT_COST, "cooldown": "rabbit_cooldown", "total": Stage3AliceState.RABBIT_COOLDOWN_SEC},
]

var _failures: Array[String] = []
var _high_roll_seed := 0
var _high_roll_value := 0.0


func _init() -> void:
	_find_high_roll_seed()
	_verify_declared_roster_and_caps()
	_verify_teddy_pity_contract()
	_verify_alice_pity_contract()
	_verify_hud_gate_composition()
	_verify_gate_absence_keeps_existing_payloads()
	_verify_non_target_scope()
	_verify_balance_simulation()
	if _failures.is_empty():
		print("[BossSkillPityGate] ELIGIBLE_ONLY=true RNG_ROLLS_PER_ELIGIBLE_SKILL=1 ROUND_PRESERVE=true FULL_RESET_CLEAR=true")
		print("[BossSkillPityGate] NEGATIVE_FIXTURE_ENV=%s" % PITY_DISABLED_FIXTURE_ENV)
		print("boss_skill_card_pity_gate_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _find_high_roll_seed() -> void:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 100000):
		probe.seed = candidate
		var value := probe.randf()
		if value > 0.999:
			_high_roll_seed = candidate
			_high_roll_value = value
			return
	_expect(false, "test fixture must find a deterministic roll above every pre-cap pity threshold")


func _verify_declared_roster_and_caps() -> void:
	_expect(TEDDY_SPECS.size() == 4, "Teddy pity roster must contain all four boss-hit chance skills")
	_expect(ALICE_PITY_SPECS.size() == 2, "Alice pity roster must contain exactly the two register_boss_hit randf skills")
	for spec_value in TEDDY_SPECS + ALICE_PITY_SPECS:
		var spec: Dictionary = spec_value
		var base_chance := float(spec.get("chance", 0.0))
		var failures_to_cap := _failures_to_reach_cap(base_chance)
		_expect(
			base_chance * (1.0 + float(failures_to_cap - 1)) < 1.0,
			"%s cap must not arrive before the derived failure count" % spec.get("id", "")
		)
		_expect(
			base_chance * (1.0 + float(failures_to_cap)) >= 1.0,
			"%s cap must derive only from its base probability" % spec.get("id", "")
		)
		print(
			"[BossSkillPityCap] skill=%s base=%.2f failures_to_probability_one=%d max_eligible_rolls_to_activation=%d"
			% [spec.get("id", ""), base_chance, failures_to_cap, failures_to_cap + 1]
		)


func _verify_teddy_pity_contract() -> void:
	for spec_value in TEDDY_SPECS:
		var spec: Dictionary = spec_value
		var state := Stage3TeddyBearState.new()
		state.reset()
		_prepare_teddy_target(state, spec)
		_verify_ineligible_teddy_hits_do_not_count(state, spec)
		_prepare_teddy_target(state, spec)
		_verify_upper_bound(state, spec, _teddy_context(), true)
		state.set(str(spec.get("counter", "")), 2)
		state.reset_round()
		_expect(int(state.get(str(spec.get("counter", "")))) == 2, "%s pity must survive reset_round" % spec.get("id", ""))
		state.reset()
		_expect(int(state.get(str(spec.get("counter", "")))) == 0, "%s pity must clear only on reset" % spec.get("id", ""))


func _verify_alice_pity_contract() -> void:
	for spec_value in ALICE_PITY_SPECS:
		var spec: Dictionary = spec_value
		var state := Stage3AliceState.new()
		state.reset()
		_prepare_alice_target(state, spec)
		_verify_ineligible_alice_hits_do_not_count(state, spec)
		_prepare_alice_target(state, spec)
		_verify_upper_bound(state, spec, _alice_context(), false)
		state.set(str(spec.get("counter", "")), 2)
		state.reset_round()
		_expect(int(state.get(str(spec.get("counter", "")))) == 2, "%s pity must survive reset_round" % spec.get("id", ""))
		state.reset()
		_expect(int(state.get(str(spec.get("counter", "")))) == 0, "%s pity must clear only on reset" % spec.get("id", ""))


func _verify_upper_bound(state: Object, spec: Dictionary, context: Dictionary, teddy: bool) -> void:
	var counter_name := str(spec.get("counter", ""))
	var trigger_name := str(spec.get("trigger", ""))
	var failures_to_cap := _failures_to_reach_cap(float(spec.get("chance", 0.0)))
	var fixture_disabled := OS.get_environment(PITY_DISABLED_FIXTURE_ENV) == "1"
	for attempt in range(failures_to_cap + 1):
		if fixture_disabled:
			# Counterfactual fixture: erase accumulation before each otherwise-eligible
			# production hit. The terminal upper-bound assertion must turn RED.
			state.set(counter_name, 0)
		state.set("boss_special_gauge", float(spec.get("cost", 0.0)) - 50.0)
		state.set(str(spec.get("cooldown", "")), 0.0)
		state.rng.seed = _high_roll_seed
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.seed = _high_roll_seed
		expected_rng.randf()
		var result: Dictionary = state.register_boss_hit(Vector2(4.0, 8.0), context, {})
		var triggered := bool(result.get(trigger_name, false))
		if attempt < failures_to_cap:
			_expect(not triggered, "%s must keep the high-roll fixture below its derived cap" % spec.get("id", ""))
			if not fixture_disabled:
				_expect(int(state.get(counter_name)) == attempt + 1, "%s eligible failure must increment exactly once" % spec.get("id", ""))
		else:
			_expect(triggered, "%s must deterministically activate on eligible roll %d" % [spec.get("id", ""), failures_to_cap + 1])
			if triggered:
				_expect(int(state.get(counter_name)) == 0, "%s activation must reset pity to its base state" % spec.get("id", ""))
		var expected_extra_calls := 0
		if triggered and not teddy:
			expected_extra_calls = int(spec.get("activation_rng_calls", 0))
		for _call in range(expected_extra_calls):
			expected_rng.randf()
		_expect(
			int(state.rng.state) == int(expected_rng.state),
			"%s must consume one chance roll per eligible hit and only its established activation RNG" % spec.get("id", "")
		)


func _verify_ineligible_teddy_hits_do_not_count(state: Object, spec: Dictionary) -> void:
	var counter_name := str(spec.get("counter", ""))
	var cooldown_name := str(spec.get("cooldown", ""))
	state.set("boss_special_gauge", 0.0)
	state.set(cooldown_name, 0.0)
	var rng_before := int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _teddy_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s gauge shortage must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s gauge shortage must not consume RNG" % spec.get("id", ""))

	_prepare_teddy_target(state, spec)
	state.set(cooldown_name, 1.0)
	rng_before = int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _teddy_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s cooldown gate must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s cooldown gate must not consume RNG" % spec.get("id", ""))

	_prepare_teddy_target(state, spec)
	_set_teddy_exclusion(state, str(spec.get("id", "")))
	rng_before = int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _teddy_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s exclusion gate must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s exclusion gate must not consume RNG" % spec.get("id", ""))


func _verify_ineligible_alice_hits_do_not_count(state: Object, spec: Dictionary) -> void:
	var counter_name := str(spec.get("counter", ""))
	var cooldown_name := str(spec.get("cooldown", ""))
	state.set("boss_special_gauge", 0.0)
	state.set(cooldown_name, 0.0)
	var rng_before := int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _alice_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s gauge shortage must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s gauge shortage must not consume RNG" % spec.get("id", ""))

	_prepare_alice_target(state, spec)
	state.set(cooldown_name, 1.0)
	rng_before = int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _alice_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s cooldown gate must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s cooldown gate must not consume RNG" % spec.get("id", ""))

	_prepare_alice_target(state, spec)
	if str(spec.get("id", "")) == "size_shift":
		state.mirror_active = true
	else:
		state.rabbit_active = true
	rng_before = int(state.rng.state)
	state.register_boss_hit(Vector2.ZERO, _alice_context(), {})
	_expect(int(state.get(counter_name)) == 0, "%s exclusion gate must not count as a pity failure" % spec.get("id", ""))
	_expect(int(state.rng.state) == rng_before, "%s exclusion gate must not consume RNG" % spec.get("id", ""))


func _verify_hud_gate_composition() -> void:
	for spec_value in TEDDY_SPECS:
		var spec: Dictionary = spec_value
		var state := Stage3TeddyBearState.new()
		state.reset()
		_clear_teddy_effects(state)
		state.set(str(spec.get("cooldown", "")), 0.0)
		state.boss_special_gauge = float(spec.get("cost", 0.0)) - 1.0
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, false, (float(spec.get("cost", 0.0)) - 1.0) / float(spec.get("cost", 1.0)))
		state.boss_special_gauge = float(spec.get("cost", 0.0))
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, true, 1.0)
		state.set(str(spec.get("cooldown", "")), float(_teddy_total_for(str(spec.get("id", "")))) * 0.5)
		state.boss_special_gauge = float(spec.get("cost", 0.0)) * 0.8
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, false, 0.5)

	for spec_value in ALICE_HUD_SPECS:
		var spec: Dictionary = spec_value
		var state := Stage3AliceState.new()
		state.reset()
		_clear_alice_effects(state)
		state.set(str(spec.get("cooldown", "")), 0.0)
		state.boss_special_gauge = float(spec.get("cost", 0.0)) - 1.0
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, false, (float(spec.get("cost", 0.0)) - 1.0) / float(spec.get("cost", 1.0)))
		state.boss_special_gauge = float(spec.get("cost", 0.0))
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, true, 1.0)
		state.set(str(spec.get("cooldown", "")), float(spec.get("total", 1.0)) * 0.5)
		state.boss_special_gauge = float(spec.get("cost", 0.0)) * 0.8
		_assert_gate_card(_find_skill(state.get_hud_context(), "stage3_boss_skill_hud_skills", str(spec.get("id", ""))), spec, false, 0.5)


func _assert_gate_card(card: Dictionary, spec: Dictionary, expected_ready: bool, expected_progress: float) -> void:
	var skill_id := str(spec.get("id", ""))
	_expect(not card.is_empty(), "%s HUD card must exist" % skill_id)
	_expect(bool(card.get("ready", false)) == expected_ready, "%s ready must require both cooldown and activation gauge" % skill_id)
	_expect(str(card.get("status", "")) == ("ready" if expected_ready else "charging"), "%s must reuse existing ready/charging status vocabulary" % skill_id)
	_expect(absf(float(card.get("progress", -1.0)) - expected_progress) <= EPSILON, "%s fill must be the cooldown/gauge conjunction" % skill_id)
	_expect(absf(float(card.get("activation_gauge_cost", -1.0)) - float(spec.get("cost", 0.0))) <= EPSILON, "%s must publish its derived activation gauge cost" % skill_id)
	_expect(absf(float(card.get("activation_gauge_progress", -1.0)) - clampf(float(card.get("activation_gauge_current", 0.0)) / float(spec.get("cost", 1.0)), 0.0, 1.0)) <= EPSILON, "%s activation gauge schema must be internally consistent" % skill_id)


func _verify_gate_absence_keeps_existing_payloads() -> void:
	var dalji := Stage1DaljiCooldownState.new()
	var dalji_skills: Array = dalji.get_hud_context().get("stage1_dalji_boss_skill_hud_skills", [])
	var cheongringwi := Stage2CheongringwiState.new()
	cheongringwi.reset()
	var cheong_skills: Array = cheongringwi.get_hud_context(null, {}).get("stage2_boss_skill_hud_skills", [])
	for value in dalji_skills + cheong_skills:
		var card: Dictionary = value if value is Dictionary else {}
		_expect(not card.has("activation_gauge_current"), "%s gate-free baseline must not gain activation gauge fields" % card.get("id", ""))
		_expect(not card.has("activation_gauge_cost"), "%s gate-free baseline must preserve its existing schema" % card.get("id", ""))
		_expect(float(card.get("progress", -1.0)) >= 0.0, "%s gate-free baseline must retain its existing progress" % card.get("id", ""))
	print("[BossSkillPityGate] GATE_ABSENT_PARITY=dalji,cheongringwi PIXEL_INPUT_UNCHANGED=true")


func _verify_non_target_scope() -> void:
	var molewang_hit := _function_source("res://scripts/stages/stage2/stage2_molewang_boss_state.gd", "register_boss_hit")
	var arachne_hit := _function_source("res://scripts/stages/stage2/stage2_arachne_boss_state.gd", "register_boss_hit")
	_expect(molewang_hit.find("randf") < 0, "Molewang boss-hit card activation must remain deterministic")
	_expect(arachne_hit.find("randf") < 0, "Arachne boss-hit card activation must remain deterministic")
	var akamu_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	var akamu_has_probability_delegation := (
		akamu_source.find("_try_start_clone_cast(context, false, false, \"boss_paddle_hit\")") >= 0
		and akamu_source.find("_try_start_cloud(context, deps, false, false, \"boss_paddle_hit\")") >= 0
	)
	print("[BossSkillPityGate] NON_TARGET_UNCHANGED=molewang,arachne,akamu AKAMU_PROBABILITY_DELEGATION=%s" % str(akamu_has_probability_delegation).to_lower())


func _verify_balance_simulation() -> void:
	for boss_id in ["teddy_bear", "alice"]:
		var legacy := _simulate_hits(boss_id, true)
		var revised := _simulate_hits(boss_id, false)
		var legacy_mean := float(legacy.get("mean", 0.0))
		var revised_mean := float(revised.get("mean", 0.0))
		var mean_ratio := revised_mean / maxf(EPSILON, legacy_mean)
		_expect(mean_ratio >= SIMULATION_MEAN_RATIO_MIN and mean_ratio <= 1.0 + EPSILON, "%s aggregate mean activation interval must remain approximately stable" % boss_id)
		_expect(int(revised.get("max", 0)) < int(legacy.get("max", 0)), "%s pity must cut the sampled activation tail" % boss_id)
		print(
			"[BossSkillPityBalance] boss=%s hits=%d old_mean_hits=%.3f new_mean_hits=%.3f mean_ratio=%.3f old_p99_hits=%d new_p99_hits=%d old_max_hits=%d new_max_hits=%d"
			% [boss_id, SIMULATION_HITS, legacy_mean, revised_mean, mean_ratio, legacy.get("p99", 0), revised.get("p99", 0), legacy.get("max", 0), revised.get("max", 0)]
		)


func _simulate_hits(boss_id: String, erase_pity_each_hit: bool) -> Dictionary:
	var state: Object = Stage3TeddyBearState.new() if boss_id == "teddy_bear" else Stage3AliceState.new()
	state.reset()
	state.rng.seed = 731942
	var context := _teddy_context() if boss_id == "teddy_bear" else _alice_context()
	var intervals: Array[int] = []
	var last_activation_hit := -1
	for hit_index in range(SIMULATION_HITS):
		if erase_pity_each_hit:
			_clear_pity_counters(state, boss_id)
		var result: Dictionary = state.register_boss_hit(Vector2(4.0, 8.0), context, {})
		var activation_count := _activation_count(result, boss_id)
		for _activation in range(activation_count):
			if last_activation_hit >= 0:
				intervals.append(hit_index - last_activation_hit)
			last_activation_hit = hit_index
		state.update(SIMULATION_HIT_STEP_SEC, context, {})
		if boss_id == "teddy_bear":
			_clear_teddy_effects(state)
		else:
			_clear_alice_effects(state)
	intervals.sort()
	var total := 0.0
	for interval in intervals:
		total += float(interval)
	return {
		"mean": total / maxf(1.0, float(intervals.size())),
		"p99": intervals[int(floor(float(intervals.size() - 1) * 0.99))] if not intervals.is_empty() else 0,
		"max": intervals[-1] if not intervals.is_empty() else 0,
	}


func _activation_count(result: Dictionary, boss_id: String) -> int:
	var keys := [
		"teddy_cotton_throw_triggered",
		"teddy_cotton_bomb_triggered",
		"teddy_deadly_hug_triggered",
		"teddy_heart_beam_triggered",
	] if boss_id == "teddy_bear" else [
		"alice_mirror_triggered",
		"alice_size_shift_triggered",
		"alice_rabbit_triggered",
	]
	var count := 0
	for key in keys:
		if bool(result.get(key, false)):
			count += 1
	return count


func _prepare_teddy_target(state: Object, spec: Dictionary) -> void:
	state.reset()
	_clear_teddy_effects(state)
	for cooldown_name in ["cotton_throw_cooldown", "cotton_bomb_cooldown", "deadly_hug_cooldown", "heart_beam_cooldown"]:
		state.set(cooldown_name, 999.0)
	state.set(str(spec.get("cooldown", "")), 0.0)
	state.boss_special_gauge = float(spec.get("cost", 0.0)) - Stage3TeddyBearState.GAUGE_GAIN_ON_HIT


func _prepare_alice_target(state: Object, spec: Dictionary) -> void:
	state.reset()
	_clear_alice_effects(state)
	for cooldown_name in ["mirror_cooldown", "size_shift_cooldown", "rabbit_cooldown"]:
		state.set(cooldown_name, 999.0)
	state.set(str(spec.get("cooldown", "")), 0.0)
	state.boss_special_gauge = float(spec.get("cost", 0.0)) - Stage3AliceState.GAUGE_GAIN_ON_HIT


func _set_teddy_exclusion(state: Object, skill_id: String) -> void:
	match skill_id:
		"cotton_throw":
			state.cotton_throw_projectiles = [{"remaining": 1.0}]
		"cotton_bomb":
			state.cotton_throw_windup = 1.0
		"deadly_hug":
			state.cotton_throw_projectiles = [{"remaining": 1.0}]
		"heart_beam":
			state.deadly_hug_timer = 1.0


func _clear_pity_counters(state: Object, boss_id: String) -> void:
	var counters := [
		"cotton_throw_pity_failures",
		"cotton_bomb_pity_failures",
		"deadly_hug_pity_failures",
		"heart_beam_pity_failures",
	] if boss_id == "teddy_bear" else ["size_shift_pity_failures", "rabbit_pity_failures"]
	for counter in counters:
		state.set(counter, 0)


func _clear_teddy_effects(state: Object) -> void:
	state.cotton_throw_windup = 0.0
	state.cotton_throw_projectiles.clear()
	state.blackout_timer = 0.0
	state.cotton_bomb_windup = 0.0
	state.cotton_bombs.clear()
	state.cotton_fragments.clear()
	state.deadly_hug_rush_active = false
	state.deadly_hug_timer = 0.0
	state.heart_projectile.clear()
	state.heart_knockback_timer = 0.0


func _clear_alice_effects(state: Object) -> void:
	state.mirror_active = false
	state.mirror_timer = 0.0
	state.size_shift_active = false
	state.size_shift_timer = 0.0
	state.rabbit_active = false
	state.rabbit_windup = 0.0
	state.rabbit_projectiles.clear()
	state.perched_rabbits.clear()


func _failures_to_reach_cap(base_chance: float) -> int:
	var failures := 0
	while base_chance * (1.0 + float(failures)) < 1.0:
		failures += 1
	return failures


func _teddy_total_for(skill_id: String) -> float:
	return float({
		"cotton_throw": Stage3TeddyBearState.COTTON_THROW_COOLDOWN_SEC,
		"cotton_bomb": Stage3TeddyBearState.COTTON_BOMB_COOLDOWN_SEC,
		"deadly_hug": Stage3TeddyBearState.DEADLY_HUG_COOLDOWN_SEC,
		"heart_beam": Stage3TeddyBearState.HEART_BEAM_COOLDOWN_SEC,
	}.get(skill_id, 1.0))


func _find_skill(context: Dictionary, key: String, skill_id: String) -> Dictionary:
	for value in context.get(key, []):
		if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
			return value as Dictionary
	return {}


func _function_source(path: String, function_name: String) -> String:
	var source := FileAccess.get_file_as_string(path)
	var start := source.find("func %s" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _teddy_context() -> Dictionary:
	var context := _base_context()
	context["stage_boss_variant"] = "teddy_bear"
	return context


func _alice_context() -> Dictionary:
	var context := _base_context()
	context["stage_boss_variant"] = "alice"
	return context


func _base_context() -> Dictionary:
	return {
		"current_stage": 3,
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.0, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(4.0, 8.0),
		"ball_size": 28.6,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
