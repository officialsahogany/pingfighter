extends SceneTree

const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage1DaljiState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage1GaksitalState := preload("res://scripts/stages/stage1/stage1_gaksital_boss_skill_cooldown_state.gd")
const Stage1PododaejangState := preload("res://scripts/stages/stage1/stage1_pododaejang_boss_skill_cooldown_state.gd")
const Stage2BossState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage2BossVariantState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")
const Stage2MolewangState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage2ArachneState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage3BossState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3BossVariantState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")
const Stage3TeddyBearState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")
const Stage3AliceState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")

const ZERO_INITIAL_FIXTURE_ENV := "BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE"
const EPSILON := 0.0001
const EXPECTED_SKILL_COUNT := 25
const VALID_CONTRACTS := ["time", "event_cycle", "score_latched"]

var _failures: Array[String] = []
var _boss_count := 0
var _skill_count := 0
var _contract_counts := {"time": 0, "event_cycle": 0, "score_latched": 0}


class FakeStage1AutoSkill:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active

	func was_used_this_round() -> bool:
		return false

	func activate(_context: Dictionary, _deps: Dictionary = {}) -> bool:
		active = true
		return true


class FakeStage2Background:
	extends RefCounted

	var quake_active := false
	var water_phase := "idle"
	var rock_count := 1

	func is_quake_active() -> bool:
		return quake_active

	func is_boss_rage_active() -> bool:
		return false

	func get_water_cannon_phase() -> String:
		return water_phase

	func get_rock_count() -> int:
		return rock_count

	func activate_quake(
		_duration: float,
		_rock_count: int,
		_enraged: bool,
		_launch_guard: bool,
		_deps: Dictionary
	) -> bool:
		quake_active = true
		return true

	func activate_water_cannon(_context: Dictionary, _deps: Dictionary) -> bool:
		water_phase = "charging"
		return true


func _init() -> void:
	_verify_catalog_coverage()
	_verify_every_reset_and_update()
	_expect(
		_skill_count == EXPECTED_SKILL_COUNT,
		"ported boss skill count changed without updating the cooldown contract: expected=%d actual=%d"
		% [EXPECTED_SKILL_COUNT, _skill_count]
	)
	_verify_every_cast_reloads_and_ticks()
	_verify_production_update_owner()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print(
		"[BossSkillCardCooldownContract] BOSSES=%d SKILLS=%d TIME=%d EVENT_CYCLE=%d SCORE_LATCHED=%d"
		% [
			_boss_count,
			_skill_count,
			int(_contract_counts.get("time", 0)),
			int(_contract_counts.get("event_cycle", 0)),
			int(_contract_counts.get("score_latched", 0)),
		]
	)
	print("[BossSkillCardCooldownContract] SINGLE_UPDATE_OWNER=true CAST_RELOAD=true NEGATIVE_FIXTURE_ENV=%s" % ZERO_INITIAL_FIXTURE_ENV)
	print("boss_skill_card_cooldown_contract_smoke: ok")
	quit(0)


func _verify_catalog_coverage() -> void:
	var catalog_ids: Array[String] = []
	for variant_value in StageBossVariantCatalog.VARIANTS.keys():
		var variant_id := str(variant_value)
		var entry: Dictionary = StageBossVariantCatalog.VARIANTS.get(variant_id, {})
		if bool(entry.get("ported", false)):
			catalog_ids.append(variant_id)
	catalog_ids.sort()
	var adapter_ids := [
		"dalji",
		"gaksi",
		"podo",
		"cheongringwi",
		"molewang",
		"arachne",
		"yeonmyo",
		"teddy_bear",
		"alice",
	]
	adapter_ids.sort()
	_expect(catalog_ids == adapter_ids, "ported boss catalog changed without a cooldown-contract adapter: catalog=%s adapters=%s" % [catalog_ids, adapter_ids])
	_boss_count = catalog_ids.size()


func _verify_every_reset_and_update() -> void:
	var use_zero_fixture := OS.get_environment(ZERO_INITIAL_FIXTURE_ENV) == "1"
	for variant_id in _variant_ids():
		var state: Object = _new_state(variant_id)
		state.reset()
		if use_zero_fixture and variant_id == "molewang":
			state.tunnel_cooldown = 0.0
		var context := _context_for(variant_id)
		var background := FakeStage2Background.new()
		var initial_skills := _skill_map(variant_id, state, context, background)
		_expect(not initial_skills.is_empty(), "%s reset must publish boss skill cards" % variant_id)
		for skill_id in initial_skills:
			_validate_initial_skill(variant_id, skill_id, initial_skills[skill_id])
			_skill_count += 1
		var initial_progress := _progress_map(initial_skills)
		_tick_state(variant_id, state, context, background, 3)
		var advanced_skills := _skill_map(variant_id, state, context, background)
		for skill_id in initial_skills:
			var initial_skill: Dictionary = initial_skills[skill_id]
			if str(initial_skill.get("cooldown_contract", "")) != "time":
				continue
			var before := float(initial_progress.get(skill_id, -1.0))
			var after := float((advanced_skills.get(skill_id, {}) as Dictionary).get("progress", -1.0))
			_expect(after > before + EPSILON, "%s/%s progress must advance across live update ticks (%.6f -> %.6f)" % [variant_id, skill_id, before, after])


func _validate_initial_skill(variant_id: String, skill_id: String, skill: Dictionary) -> void:
	for key in [
		"id",
		"status",
		"cooldown_remaining",
		"cooldown_total",
		"progress",
		"ready",
		"cooldown_contract",
		"initial_ready_allowed",
	]:
		_expect(skill.has(key), "%s/%s reset card is missing required key %s" % [variant_id, skill_id, key])
	var total := float(skill.get("cooldown_total", 0.0))
	var remaining := float(skill.get("cooldown_remaining", -1.0))
	var progress := float(skill.get("progress", -1.0))
	var ready := bool(skill.get("ready", false))
	var allowed := bool(skill.get("initial_ready_allowed", false))
	var contract := str(skill.get("cooldown_contract", ""))
	_expect(str(skill.get("id", "")) == skill_id, "%s/%s card id must be stable" % [variant_id, skill_id])
	_expect(total > EPSILON, "%s/%s cooldown_total must be positive (got %.6f)" % [variant_id, skill_id, total])
	_expect(remaining >= -EPSILON, "%s/%s cooldown_remaining must be non-negative" % [variant_id, skill_id])
	_expect(progress >= -EPSILON and progress <= 1.0 + EPSILON, "%s/%s progress must stay inside 0..1" % [variant_id, skill_id])
	_expect(contract in VALID_CONTRACTS, "%s/%s has unknown cooldown_contract=%s" % [variant_id, skill_id, contract])
	if _contract_counts.has(contract):
		_contract_counts[contract] = int(_contract_counts.get(contract, 0)) + 1
	if ready or progress >= 1.0 - EPSILON:
		_expect(allowed, "%s/%s reset is immediately ready without initial_ready_allowed=true" % [variant_id, skill_id])
	else:
		_expect(not allowed, "%s/%s declares an unused initial-ready exception" % [variant_id, skill_id])


func _verify_every_cast_reloads_and_ticks() -> void:
	for variant_id in _variant_ids():
		var probe_state: Object = _new_state(variant_id)
		probe_state.reset()
		var probe_context := _context_for(variant_id)
		var probe_background := FakeStage2Background.new()
		var initial_skills := _skill_map(variant_id, probe_state, probe_context, probe_background)
		for skill_id in initial_skills:
			var contract := str((initial_skills[skill_id] as Dictionary).get("cooldown_contract", ""))
			var state: Object = _new_state(variant_id)
			state.reset()
			var context := _context_for(variant_id)
			var background := FakeStage2Background.new()
			var cast_fixture := _cast_skill(variant_id, skill_id, state, context, background)
			_expect(bool(cast_fixture.get("cast", false)), "%s/%s contract fixture must traverse its activation owner" % [variant_id, skill_id])
			if variant_id == "yeonmyo" and skill_id == "psycho_ball":
				# Psychoball intentionally freezes the whole Stage 3 update during its
				# hitstop. Clear that production-owned window before measuring the
				# cooldown's one-and-only ticking owner.
				while state.is_psychoball_hitstop_active():
					state.update(0.05, context, {})
			var cast_skill: Dictionary = _skill_map(variant_id, state, context, background).get(skill_id, {})
			_expect(not cast_skill.is_empty(), "%s/%s must remain published after cast" % [variant_id, skill_id])
			if contract == "score_latched":
				_expect(str(cast_skill.get("status", "")) == "casting", "%s/%s score-latched cast must publish casting" % [variant_id, skill_id])
				continue
			if contract == "event_cycle":
				state._stop_friend_moles()
				cast_skill = _skill_map(variant_id, state, context, background).get(skill_id, {})
			if variant_id == "cheongringwi" and skill_id == "speed_defense":
				state.update(Stage2BossState.SPEED_DEFENSE_DURATION_SEC, context, {"stage_background": background})
				cast_skill = _skill_map(variant_id, state, context, background).get(skill_id, {})
			var reloaded_remaining := float(cast_skill.get("cooldown_remaining", 0.0))
			_expect(reloaded_remaining > EPSILON, "%s/%s cast must reload a positive cooldown" % [variant_id, skill_id])
			_advance_after_cast(variant_id, state, context, background)
			var advanced_skill: Dictionary = _skill_map(variant_id, state, context, background).get(skill_id, {})
			var advanced_remaining := float(advanced_skill.get("cooldown_remaining", reloaded_remaining))
			var expected_drop := _expected_tick_drop(variant_id, contract)
			_expect(
				absf((reloaded_remaining - advanced_remaining) - expected_drop) <= 0.001,
				"%s/%s cooldown must tick exactly once after cast (expected drop %.6f, got %.6f)"
				% [variant_id, skill_id, expected_drop, reloaded_remaining - advanced_remaining]
			)


func _cast_skill(
	variant_id: String,
	skill_id: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background
) -> Dictionary:
	if variant_id in ["dalji", "gaksi", "podo"]:
		var runtime: Dictionary = state._get_runtime(skill_id)
		runtime["timer"] = float(runtime.get("duration", 1.0))
		runtime["ready"] = true
		runtime["status"] = "ready"
		state.skill_runtime[skill_id] = runtime
		if skill_id in ["whip", "fan_wind", "arrest_rope"]:
			return {"cast": bool(state.consume_on_hit(skill_id, context, {}))}
		var auto_skill := FakeStage1AutoSkill.new()
		var dep_key: String = str({
			"spinning_top": "stage1_dalji_spinning_top_skill_state",
			"fan_throw": "stage1_gaksital_fan_throw_skill_state",
			"patrol_guards": "stage1_pododaejang_patrol_guards_skill_state",
		}.get(skill_id, ""))
		state.update(0.0, context, {dep_key: auto_skill})
		return {"cast": auto_skill.active}
	match variant_id:
		"cheongringwi":
			match skill_id:
				"jungle_quake":
					state.quake_cooldown = 0.0
					return {"cast": bool(state._activate_quake_from_cooldown(context, {}, background))}
				"water_cannon":
					state.water_cannon_delay = 0.0
					return {"cast": bool(state._update_water_cannon_schedule(context, {}, background))}
				"speed_defense":
					state._activate_speed_defense(380.0, {}, context)
					return {"cast": state.speed_defense_active}
		"molewang":
			match skill_id:
				"tunnel_raid":
					state._activate_tunnel(context, {})
					return {"cast": state.tunnel_active}
				"spinning_claw":
					state.boss_special_gauge = Stage2MolewangState.SPINNING_CLAW_COST
					state.spinning_claw_cooldown = 0.0
					var result: Dictionary = state.register_boss_hit(Vector2(2.0, 8.0), context, {})
					return {"cast": bool(result.get("molewang_spinning_claw_triggered", false))}
				"friend_moles":
					state.handle_score_event("player", {"player_score": 4}, {})
					state.reset_round()
					state.update(0.0, context, {})
					return {"cast": state.friend_moles_active}
		"arachne":
			match skill_id:
				"web_trap":
					state._activate_web_trap(context, {})
					return {"cast": not state.web_trap_projectile.is_empty()}
				"web_rescue":
					state.boss_special_gauge = Stage2ArachneState.WEB_RESCUE_COST
					state.web_rescue_cooldown = 0.0
					context["ball_pos"] = Vector2(380.0, 0.0)
					context["ball_vel"] = Vector2(0.0, -8.0)
					state.update(0.0, context, {})
					return {"cast": state.web_rescue_active}
				"spider_rage":
					state.handle_score_event("player", {"player_score": 4}, {})
					state.reset_round()
					return {"cast": state.rage_active}
		"yeonmyo":
			match skill_id:
				# WIP refactor moved these activations out of the aggregate state and
				# into per-skill owner modules. Reach the real owners so the seal keeps
				# traversing the production activation path.
				"tear_shower":
					state.get("_tear_shower_state").activate(context, {})
				"curse_chest":
					state.get("_curse_chest_state").activate({})
				"psycho_ball":
					state.get("_psychoball_state").activate(context)
			return {"cast": true}
		"teddy_bear":
			match skill_id:
				"cotton_throw": state._activate_cotton_throw({})
				"cotton_bomb": state._activate_cotton_bomb({})
				"deadly_hug": state._activate_deadly_hug(context, {})
				"heart_beam": state._activate_heart_beam(context, {})
			return {"cast": true}
		"alice":
			match skill_id:
				"mirror_world": state._activate_mirror({})
				"size_shift": state._activate_size_shift(context, {}, 2.0)
				"rabbit_projectile": state._activate_rabbits()
			return {"cast": true}
	return {"cast": false}


func _advance_after_cast(
	variant_id: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background
) -> void:
	if variant_id in ["dalji", "gaksi", "podo"]:
		state.update(1.0, context, {})
	elif variant_id == "cheongringwi":
		state.update(0.05, context, {"stage_background": background})
	else:
		state.update(0.05, context, {})


func _expected_tick_drop(variant_id: String, contract: String) -> float:
	if variant_id in ["dalji", "gaksi", "podo"]:
		return 1.0 / 60.0
	if contract == "event_cycle":
		return 1.0 / float(Stage2MolewangState.PHYSICS_TICKS_PER_SECOND)
	return 0.05


func _verify_production_update_owner() -> void:
	var controller := BattleEffectsUpdateController.new()
	for variant_id in ["gaksi", "podo"]:
		var state: Object = _new_state(variant_id)
		state.reset()
		var context := _context_for(variant_id)
		var dep_key := "stage1_gaksital_boss_skill_cooldown_state" if variant_id == "gaksi" else "stage1_pododaejang_boss_skill_cooldown_state"
		controller.update(1.0 / 60.0, context, {dep_key: state})
		var first_skill: Dictionary = state.skill_runtime.values()[0]
		_expect(absf(float(first_skill.get("timer", 0.0)) - 1.0) <= EPSILON, "%s production controller must tick its cooldown exactly once" % variant_id)
	for variant_id in ["molewang", "arachne"]:
		var state := Stage2BossVariantState.new()
		state.reset()
		var context := _context_for(variant_id)
		state.update(0.0, context, {})
		controller.update(0.05, context, {"stage2_boss_skill_state": state})
		var actual: float = float(state.molewang_state.tunnel_cooldown) if variant_id == "molewang" else float(state.arachne_state.web_trap_cooldown)
		var initial: float = Stage2MolewangState.TUNNEL_INITIAL_COOLDOWN_SEC if variant_id == "molewang" else Stage2ArachneState.WEB_TRAP_INITIAL_COOLDOWN_SEC
		_expect(absf(float(actual) - float(initial) + 0.05) <= EPSILON, "%s production controller must tick its cooldown exactly once" % variant_id)
	for variant_id in ["teddy_bear", "alice"]:
		var state := Stage3BossVariantState.new()
		state.reset()
		var context := _context_for(variant_id)
		state.update(0.0, context, {})
		controller.update(0.05, context, {"stage3_boss_skill_state": state})
		var actual: float = float(state.teddy_bear_state.cotton_throw_cooldown) if variant_id == "teddy_bear" else float(state.alice_state.mirror_cooldown)
		var initial: float = Stage3TeddyBearState.COTTON_THROW_INITIAL_COOLDOWN_SEC if variant_id == "teddy_bear" else Stage3AliceState.MIRROR_INITIAL_COOLDOWN_SEC
		_expect(absf(float(actual) - float(initial) + 0.05) <= EPSILON, "%s production controller must tick its cooldown exactly once" % variant_id)


func _tick_state(
	variant_id: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background,
	count: int
) -> void:
	for _index in range(count):
		if variant_id in ["dalji", "gaksi", "podo"]:
			state.update(1.0, context, {})
		elif variant_id == "cheongringwi":
			state.update(0.05, context, {"stage_background": background})
		else:
			state.update(0.05, context, {})


func _skill_map(
	variant_id: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background
) -> Dictionary:
	var hud_context: Dictionary
	if variant_id in ["dalji", "gaksi", "podo"]:
		hud_context = state.get_hud_context()
	elif variant_id in ["cheongringwi", "molewang", "arachne"]:
		hud_context = state.get_hud_context(background, context)
	else:
		hud_context = state.get_hud_context(null, context)
	var skills_key := "stage%d_boss_skill_hud_skills" % int(context.get("current_stage", 0))
	if int(context.get("current_stage", 0)) == 1:
		skills_key = "stage1_%s_boss_skill_hud_skills" % {
			"dalji": "dalji",
			"gaksi": "gaksital",
			"podo": "pododaejang",
		}.get(variant_id, variant_id)
	var result := {}
	for value in hud_context.get(skills_key, []):
		if value is Dictionary:
			var skill: Dictionary = value
			result[str(skill.get("id", ""))] = skill
	return result


func _progress_map(skills: Dictionary) -> Dictionary:
	var result := {}
	for skill_id in skills:
		result[skill_id] = float((skills[skill_id] as Dictionary).get("progress", -1.0))
	return result


func _new_state(variant_id: String) -> Object:
	match variant_id:
		"dalji": return Stage1DaljiState.new()
		"gaksi": return Stage1GaksitalState.new()
		"podo": return Stage1PododaejangState.new()
		"cheongringwi": return Stage2BossState.new()
		"molewang": return Stage2MolewangState.new()
		"arachne": return Stage2ArachneState.new()
		"yeonmyo": return Stage3BossState.new()
		"teddy_bear": return Stage3TeddyBearState.new()
		"alice": return Stage3AliceState.new()
	return null


func _variant_ids() -> Array[String]:
	return [
		"dalji",
		"gaksi",
		"podo",
		"cheongringwi",
		"molewang",
		"arachne",
		"yeonmyo",
		"teddy_bear",
		"alice",
	]


func _context_for(variant_id: String) -> Dictionary:
	var stage := int(StageBossVariantCatalog.VARIANTS.get(variant_id, {}).get("stage", 0))
	return {
		"current_stage": stage,
		"stage1_boss_variant": variant_id,
		"stage_boss_variant": variant_id,
		"ball_active": true,
		"waiting_for_serve": false,
		"player_score": 4,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 350.0),
		"ball_vel": Vector2(2.0, 8.0),
		"ball_size": 28.6,
		"dash_snapshot": {"active": false},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
