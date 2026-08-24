extends SceneTree

const BattleEffectsUpdateController := preload("res://scripts/effects/battle_effects_update_controller.gd")
const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const GameplayActorModuleCatalog := preload(
	"res://scripts/resources/gameplay_actor_module_catalog.gd"
)
const Stage1DaljiCooldownState := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_cooldown_state.gd")
const Stage2BossState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage2BossVariantState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")
const Stage2MolewangState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage2ArachneState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage3BossVariantState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")
const Stage3TeddyBearState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")
const Stage3AliceState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage4MapState := preload("res://scripts/stages/stage4/stage4_map_state.gd")
const Stage4PillarBackground := preload("res://scripts/stages/stage4/stage4_pillar_background.gd")

const PRODUCER_ROOT := "res://scripts/stages"
const ZERO_INITIAL_FIXTURE_ENV := "BOSS_SKILL_CARD_ZERO_INITIAL_FIXTURE"
const AUTO_TRIGGER_BLOCK_FIXTURE_ENV := "BOSS_SKILL_BLOCK_AUTO_TRIGGER_FIXTURE"
const ZERO_ROUND_RESET_FIXTURE_ENV := "BOSS_SKILL_CARD_ZERO_ROUND_RESET_FIXTURE"
const EPSILON := 0.0001
const VALID_CONTRACTS := [
	"time",
	"deferred_time",
	"event_cycle",
	"score_latched",
	"resource_gauge",
	"placeholder",
]
const ON_BOSS_HIT_SKILL_IDS := [
	"whip",
	"fan_wind",
	"arrest_rope",
	"spinning_claw",
	"web_trap",
	"psycho_ball",
	"cotton_throw",
	"cotton_bomb",
	"deadly_hug",
	"heart_beam",
	"mirror_world",
	"size_shift",
	"rabbit_projectile",
	"meditation",
	"hongryun_inferno",
	"stage7_clone",
	"stage7_cloud",
]

var _failures: Array[String] = []
var _producers: Array[Dictionary] = []
var _boss_count := 0
var _skill_count := 0
var _trigger_instant_count := 0
var _trigger_on_boss_hit_count := 0
var _trigger_match_count := 0
var _round_preserve_skill_count := 0
var _round_reset_exception_count := 0
var _round_transition_check_count := 0
var _round_cast_cancel_count := 0
var _vision_count := 0
var _vision_round_preserve_count := 0
var _vision_cooldown_trio_count := 0
var _contract_counts := {
	"time": 0,
	"deferred_time": 0,
	"event_cycle": 0,
	"score_latched": 0,
	"resource_gauge": 0,
	"placeholder": 0,
}


class FakeStage1AutoSkill:
	extends RefCounted

	var active := false
	var block_activation := false

	func is_active() -> bool:
		return active

	func was_used_this_round() -> bool:
		return false

	func activate(_context: Dictionary, _deps: Dictionary = {}) -> bool:
		if block_activation:
			return false
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
	if OS.get_environment(AUTO_TRIGGER_BLOCK_FIXTURE_ENV) == "1":
		_verify_auto_trigger_negative_fixture()
		for failure in _failures:
			push_error(failure)
		quit(1 if not _failures.is_empty() else 0)
		return
	_discover_all_producers()
	_verify_common_vision_cooldowns()
	_verify_every_reset_and_update()
	_verify_target_cast_round_cleanup_preserves()
	_verify_every_cast_reloads_and_ticks()
	_verify_production_update_owner()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print(
		"[BossSkillCardCooldownContract] BOSSES=%d SKILLS=%d TIME=%d DEFERRED_TIME=%d EVENT_CYCLE=%d SCORE_LATCHED=%d RESOURCE_GAUGE=%d PLACEHOLDER=%d ROUND_TRANSITION_CHECKS=%d ROUND_PRESERVE=%d ROUND_RESET_EXCEPTIONS=%d ROUND_CAST_CANCEL=%d"
		% [
			_boss_count,
			_skill_count,
			int(_contract_counts.get("time", 0)),
			int(_contract_counts.get("deferred_time", 0)),
			int(_contract_counts.get("event_cycle", 0)),
			int(_contract_counts.get("score_latched", 0)),
			int(_contract_counts.get("resource_gauge", 0)),
			int(_contract_counts.get("placeholder", 0)),
			_round_transition_check_count,
			_round_preserve_skill_count,
			_round_reset_exception_count,
			_round_cast_cancel_count,
		]
	)
	print(
		"[BossSkillCardCooldownContract] DISCOVERY=runtime_hud_producers+common_vision_catalog STAGES=1-8 SINGLE_UPDATE_OWNER=true CAST_RELOAD=true ROUND_TRANSITION=contract_metadata NEGATIVE_FIXTURE_ENVS=%s,%s"
		% [ZERO_INITIAL_FIXTURE_ENV, ZERO_ROUND_RESET_FIXTURE_ENV]
	)
	print(
		"[BossSkillCardCooldownContract] VISIONS=%d VISION_ROUND_PRESERVE=%d VISION_COOLDOWN_TRIO=%d"
		% [_vision_count, _vision_round_preserve_count, _vision_cooldown_trio_count]
	)
	print(
		"[BossSkillCardCooldownContract] TRIGGER_DECLARATIONS=%d TRIGGER_INSTANT=%d TRIGGER_ON_BOSS_HIT=%d TRIGGER_MATCH=%d AUTO_BLOCK_NEGATIVE_FIXTURE_ENV=%s"
		% [_skill_count, _trigger_instant_count, _trigger_on_boss_hit_count, _trigger_match_count, AUTO_TRIGGER_BLOCK_FIXTURE_ENV]
	)
	print("boss_skill_card_cooldown_contract_smoke: ok")
	quit(0)


func _verify_auto_trigger_negative_fixture() -> void:
	var state := Stage1DaljiCooldownState.new()
	var runtime: Dictionary = state._get_runtime("spinning_top")
	runtime["timer"] = float(runtime.get("duration", 1.0))
	runtime["ready"] = true
	runtime["status"] = "ready"
	state.skill_runtime["spinning_top"] = runtime
	var blocked_auto_skill := FakeStage1AutoSkill.new()
	blocked_auto_skill.block_activation = true
	state.update(0.0, _base_context(1), {"stage1_dalji_spinning_top_skill_state": blocked_auto_skill})
	_expect(blocked_auto_skill.active, "instant-declared spinning_top must activate automatically when its card is full")


func _discover_all_producers() -> void:
	var paths: Array[String] = []
	for stage_dir_value in DirAccess.get_directories_at(PRODUCER_ROOT):
		var stage_dir := str(stage_dir_value)
		if not stage_dir.begins_with("stage"):
			continue
		var directory_path := PRODUCER_ROOT.path_join(stage_dir)
		for file_value in DirAccess.get_files_at(directory_path):
			var file_name := str(file_value)
			if not file_name.ends_with(".gd"):
				continue
			var path := directory_path.path_join(file_name)
			var source := FileAccess.get_file_as_string(path)
			if source.find("func get_hud_context") < 0:
				continue
			# Stage 2/3 variant routers delegate to the same concrete owners found
			# below. They are call paths, not additional bosses.
			if file_name.ends_with("_boss_variant_skill_state.gd"):
				continue
			paths.append(path)
	paths.sort()

	var covered_stages := {}
	for path in paths:
		var state := _new_state(path)
		if state == null:
			continue
		var context := _context_for_path(path)
		var skills := _skill_map(path, state, context, FakeStage2Background.new())
		if skills.is_empty():
			continue
		var skill_ids: Array[String] = []
		for skill_id_value in skills.keys():
			skill_ids.append(str(skill_id_value))
		skill_ids.sort()
		var stage := int(context.get("current_stage", 0))
		covered_stages[stage] = true
		_producers.append({
			"id": path.get_file().trim_suffix(".gd"),
			"path": path,
			"stage": stage,
			"skill_ids": skill_ids,
		})
	_boss_count = _producers.size()
	_expect(_boss_count > 0, "runtime HUD producer discovery must find at least one boss")
	for stage in range(1, 9):
		_expect(bool(covered_stages.get(stage, false)), "runtime HUD producer discovery must cover Stage %d" % stage)


func _verify_common_vision_cooldowns() -> void:
	for skill_id in CommonSkillCatalog.get_all_skill_ids():
		var skill_data := CommonSkillCatalog.get_skill_data(skill_id)
		if not bool(skill_data.get("vision_chosik", false)):
			continue
		_vision_count += 1
		var boss_id := str(skill_data.get("boss_id", "")).strip_edges()
		var state_key := "%s_vision_chosik_state" % boss_id
		var module_data: Dictionary = GameplayActorModuleCatalog.MODULES.get(state_key, {})
		_expect(not module_data.is_empty(), "%s must resolve through gameplay actor modules" % skill_id)
		var path := str(module_data.get("path", ""))
		var state := _new_state(path)
		if state == null:
			continue
		var duration := float(skill_data.get("cooldown", 0.0))
		_expect(duration > 0.0, "%s Vision cooldown must be positive" % skill_id)
		state.set("cooldown_duration", duration)
		state.set("cooldown_remaining", duration)
		_call_reset_round(state, state_key)
		var after_round := float(state.get("cooldown_remaining"))
		_expect(
			is_equal_approx(after_round, duration),
			"%s reset_round must preserve Vision cooldown" % skill_id
		)
		if is_equal_approx(after_round, duration):
			_vision_round_preserve_count += 1
		var advance_count := int(state.call("advance_cooldowns_by_msec", 1000))
		var after_advance := float(state.get("cooldown_remaining"))
		var reduce_count := int(state.call("reduce_all_cooldowns_by_fraction", 0.2))
		var after_reduce := float(state.get("cooldown_remaining"))
		state.call("reset_cooldowns")
		var after_reset := float(state.get("cooldown_remaining"))
		var trio_green := (
			advance_count == 1
			and is_equal_approx(after_advance, maxf(0.0, duration - 1.0))
			and reduce_count == 1
			and is_equal_approx(after_reduce, maxf(0.0, duration - 1.0 - duration * 0.2))
			and is_zero_approx(after_reset)
		)
		_expect(trio_green, "%s must satisfy the Vision cooldown trio" % skill_id)
		if trio_green:
			_vision_cooldown_trio_count += 1

func _verify_every_reset_and_update() -> void:
	var use_zero_fixture := OS.get_environment(ZERO_INITIAL_FIXTURE_ENV) == "1"
	for producer in _producers:
		var path := str(producer.get("path", ""))
		var producer_id := str(producer.get("id", ""))
		var state := _new_state(path)
		var context := _context_for_path(path)
		var background := FakeStage2Background.new()
		if use_zero_fixture and path.ends_with("stage7_akamu_state.gd"):
			state.debug_set_clone_cooldown_remaining(0.0)
		var initial_skills := _skill_map(path, state, context, background)
		_expect(not initial_skills.is_empty(), "%s reset must publish boss skill cards" % producer_id)
		var discovered_ids: Array[String] = []
		for skill_id_value in initial_skills.keys():
			var skill_id := str(skill_id_value)
			discovered_ids.append(skill_id)
			_validate_initial_skill(producer_id, skill_id, initial_skills[skill_id])
			_skill_count += 1
		discovered_ids.sort()
		_expect(
			discovered_ids == (producer.get("skill_ids", []) as Array),
			"%s skill roster changed between discovery and reset: discovered=%s reset=%s"
			% [producer_id, producer.get("skill_ids", []), discovered_ids]
		)

		# Additive activation-gauge fields make card fill the conjunction of the
		# cooldown and resource gates. Prime only that optional gate so this GRT-060
		# leg continues to isolate the live cooldown owner's forward progress;
		# producers without the new fields retain the exact historical path.
		_prime_optional_activation_gates(state, initial_skills)
		initial_skills = _skill_map(path, state, context, background)
		var initial_progress := _progress_map(initial_skills)
		_advance_initial_contracts(path, state, context, background, initial_skills)
		var advanced_skills := _skill_map(path, state, context, background)
		for skill_id in initial_skills:
			var initial_skill: Dictionary = initial_skills[skill_id]
			var contract := str(initial_skill.get("cooldown_contract", ""))
			if contract not in ["time", "deferred_time", "resource_gauge"]:
				continue
			var before := float(initial_progress.get(skill_id, -1.0))
			var after := float((advanced_skills.get(skill_id, {}) as Dictionary).get("progress", -1.0))
			_expect(
				after > before + EPSILON,
				"%s/%s progress must advance through its live owner (%.6f -> %.6f)"
				% [producer_id, skill_id, before, after]
			)
		_verify_round_transition_preserves(path, producer_id, state, context, background, advanced_skills)


func _verify_round_transition_preserves(
	path: String,
	producer_id: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background,
	advanced_skills: Dictionary
) -> void:
	var preserve_ids: Array[String] = []
	var reset_exception_ids: Array[String] = []
	for skill_id_value in advanced_skills.keys():
		var skill_id := str(skill_id_value)
		var skill: Dictionary = advanced_skills[skill_id]
		var contract := str(skill.get("cooldown_contract", ""))
		if contract not in ["time", "deferred_time", "event_cycle"]:
			continue
		if str(skill.get("round_transition_policy", "preserve")) == "reset":
			reset_exception_ids.append(skill_id)
		else:
			preserve_ids.append(skill_id)
	if preserve_ids.is_empty() and reset_exception_ids.is_empty():
		return
	# event_cycle uses a score latch to expose its tick rail. Consume a few live
	# ticks while still pending so this same reset_round call covers the historical
	# friend_moles branch that zeroed the remaining ticks.
	if "friend_moles" in preserve_ids:
		state.handle_score_event("player", {"player_score": 4}, {})
		_tick_state(path, state, context, background, 3)
	var before_skills := _skill_map(path, state, context, background)
	var before_remaining := {}
	var before_totals := {}
	var checked_ids := preserve_ids + reset_exception_ids
	preserve_ids.sort()
	reset_exception_ids.sort()
	for skill_id in checked_ids:
		var skill: Dictionary = before_skills.get(skill_id, {})
		var remaining := _round_remaining(state, skill_id, skill)
		var total := _round_total(skill_id, skill)
		_expect(
			remaining > EPSILON and remaining < total - EPSILON,
			"%s/%s round probe must partially consume cooldown before reset_round (remaining %.6f / total %.6f)"
			% [producer_id, skill_id, remaining, total]
		)
		before_remaining[skill_id] = remaining
		before_totals[skill_id] = total

	_call_reset_round(state, producer_id)
	if OS.get_environment(ZERO_ROUND_RESET_FIXTURE_ENV) == "1" and path.ends_with("stage2_molewang_boss_state.gd"):
		# Test-only counterfactual: reproduce the removed round-boundary write
		# without teaching production code about a test environment variable.
		state.spinning_claw_cooldown = 0.0
	var after_skills := _skill_map(path, state, context, background)
	for skill_id in preserve_ids:
		var after_skill: Dictionary = after_skills.get(skill_id, {})
		var before := float(before_remaining.get(skill_id, -1.0))
		var after := _round_remaining(state, skill_id, after_skill)
		_expect(
			absf(after - before) <= EPSILON,
			"%s/%s reset_round must preserve cooldown remaining (%.6f -> %.6f)"
			% [producer_id, skill_id, before, after]
		)
		_round_preserve_skill_count += 1
		_round_transition_check_count += 1
	for skill_id in reset_exception_ids:
		var after_skill: Dictionary = after_skills.get(skill_id, {})
		var before := float(before_remaining.get(skill_id, -1.0))
		var total := float(before_totals.get(skill_id, -1.0))
		var after := _round_remaining(state, skill_id, after_skill)
		_expect(
			after > before + EPSILON and absf(after - total) <= EPSILON,
			"%s/%s declared round reset must re-arm its documented total (%.6f -> %.6f / total %.6f)"
			% [producer_id, skill_id, before, after, total]
		)
		_round_transition_check_count += 1


func _verify_target_cast_round_cleanup_preserves() -> void:
	var specs := [
		{
			"path": "res://scripts/stages/stage2/stage2_molewang_boss_state.gd",
			"skills": ["tunnel_raid", "spinning_claw", "friend_moles"],
		},
		{
			"path": "res://scripts/stages/stage3/stage3_alice_boss_state.gd",
			"skills": ["mirror_world", "size_shift", "rabbit_projectile"],
		},
	]
	for spec_value in specs:
		var spec: Dictionary = spec_value
		var path := str(spec.get("path", ""))
		for skill_id_value in spec.get("skills", []):
			var skill_id := str(skill_id_value)
			var producer_id := path.get_file().trim_suffix(".gd")
			var state := _new_state(path)
			var context := _context_for_path(path)
			var background := FakeStage2Background.new()
			var cast := _cast_skill(skill_id, state, context, background)
			_expect(cast, "%s/%s cast-round fixture must activate" % [producer_id, skill_id])
			if not cast:
				continue
			var before_skill: Dictionary = _skill_map(path, state, context, background).get(skill_id, {})
			var before := _round_remaining(state, skill_id, before_skill)
			_expect(before > EPSILON, "%s/%s active cast must have a positive reloaded cooldown" % [producer_id, skill_id])
			_call_reset_round(state, producer_id)
			var after_skill: Dictionary = _skill_map(path, state, context, background).get(skill_id, {})
			var after := _round_remaining(state, skill_id, after_skill)
			_expect(absf(after - before) <= EPSILON, "%s/%s cast cancellation must preserve cooldown (%.6f -> %.6f)" % [producer_id, skill_id, before, after])
			_expect(_cast_transients_cleared(state, skill_id), "%s/%s reset_round must cancel active cast transients" % [producer_id, skill_id])
			_round_cast_cancel_count += 1


func _cast_transients_cleared(state: Object, skill_id: String) -> bool:
	match skill_id:
		"tunnel_raid":
			return not bool(state.tunnel_active) and str(state.tunnel_phase) == "idle"
		"spinning_claw":
			return float(state.spinning_claw_timer) <= EPSILON
		"friend_moles":
			return not bool(state.friend_moles_active) and (state.friend_moles as Array).is_empty()
		"mirror_world":
			return not bool(state.mirror_active) and float(state.mirror_timer) <= EPSILON
		"size_shift":
			return not bool(state.size_shift_active) and float(state.size_shift_timer) <= EPSILON and absf(float(state.size_shift_scale) - 1.0) <= EPSILON
		"rabbit_projectile":
			return not bool(state.rabbit_active) and float(state.rabbit_windup) <= EPSILON and (state.rabbit_projectiles as Array).is_empty()
	return false


func _round_remaining(state: Object, skill_id: String, skill: Dictionary) -> float:
	if skill_id == "friend_moles":
		return float(state.friend_moles_cooldown_ticks_remaining) / float(Stage2MolewangState.PHYSICS_TICKS_PER_SECOND)
	if skill_id == "speed_defense":
		return maxf(0.0, Stage2BossState.SPEED_DEFENSE_INTERVAL_SEC - float(state.speed_defense_since_activation))
	return float(skill.get("cooldown_remaining", -1.0))


func _round_total(skill_id: String, skill: Dictionary) -> float:
	if skill_id == "speed_defense":
		return Stage2BossState.SPEED_DEFENSE_INTERVAL_SEC
	return float(skill.get("cooldown_total", 0.0))


func _call_reset_round(state: Object, producer_id: String) -> void:
	_expect(state.has_method("reset_round"), "%s must implement reset_round for the round cooldown contract" % producer_id)
	if not state.has_method("reset_round"):
		return
	var args: Array = []
	if _method_argument_count(state, "reset_round") >= 1:
		args = [{}]
	state.callv("reset_round", args)


func _prime_optional_activation_gates(state: Object, skills: Dictionary) -> void:
	var required_gauge := 0.0
	for skill_value in skills.values():
		var skill: Dictionary = skill_value if skill_value is Dictionary else {}
		if skill.has("activation_gauge_cost"):
			required_gauge = maxf(required_gauge, float(skill.get("activation_gauge_cost", 0.0)))
	if required_gauge <= 0.0:
		return
	state.set("boss_special_gauge", required_gauge)


func _validate_initial_skill(producer_id: String, skill_id: String, skill: Dictionary) -> void:
	for key in [
		"id",
		"status",
		"cooldown_remaining",
		"cooldown_total",
		"progress",
		"ready",
		"cooldown_contract",
		"initial_ready_allowed",
		"trigger_type",
	]:
		_expect(skill.has(key), "%s/%s reset card is missing required key %s" % [producer_id, skill_id, key])
	var total := float(skill.get("cooldown_total", 0.0))
	var remaining := float(skill.get("cooldown_remaining", -1.0))
	var progress := float(skill.get("progress", -1.0))
	var ready := bool(skill.get("ready", false))
	var allowed := bool(skill.get("initial_ready_allowed", false))
	var contract := str(skill.get("cooldown_contract", ""))
	var trigger_type := str(skill.get("trigger_type", ""))
	_expect(str(skill.get("id", "")) == skill_id, "%s/%s card id must be stable" % [producer_id, skill_id])
	_expect(total > EPSILON, "%s/%s cooldown_total must be positive (got %.6f)" % [producer_id, skill_id, total])
	_expect(remaining >= -EPSILON, "%s/%s cooldown_remaining must be non-negative" % [producer_id, skill_id])
	_expect(progress >= -EPSILON and progress <= 1.0 + EPSILON, "%s/%s progress must stay inside 0..1" % [producer_id, skill_id])
	_expect(contract in VALID_CONTRACTS, "%s/%s has unknown cooldown_contract=%s" % [producer_id, skill_id, contract])
	_expect(BossSkillTriggerClass.is_valid(trigger_type), "%s/%s has missing or invalid trigger_type=%s" % [producer_id, skill_id, trigger_type])
	var expected_trigger := _expected_trigger_type(skill_id)
	_expect(trigger_type == expected_trigger, "%s/%s trigger declaration must match production behavior (expected=%s got=%s)" % [producer_id, skill_id, expected_trigger, trigger_type])
	if trigger_type == expected_trigger:
		_trigger_match_count += 1
	if trigger_type == BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT:
		_trigger_on_boss_hit_count += 1
	elif trigger_type == BossSkillTriggerClass.TRIGGER_INSTANT:
		_trigger_instant_count += 1
	var round_policy := str(skill.get("round_transition_policy", "preserve"))
	if skill.has("round_transition_policy"):
		_expect(contract in ["time", "deferred_time", "event_cycle"], "%s/%s round transition policy is only valid for cooldown rails" % [producer_id, skill_id])
		_expect(round_policy == "reset", "%s/%s explicit round transition policy must declare the exceptional reset" % [producer_id, skill_id])
		_expect(not str(skill.get("round_transition_reason", "")).is_empty(), "%s/%s round reset exception must publish a reason" % [producer_id, skill_id])
		if round_policy == "reset":
			_round_reset_exception_count += 1
	if _contract_counts.has(contract):
		_contract_counts[contract] = int(_contract_counts.get(contract, 0)) + 1
	if contract == "placeholder":
		_expect(not bool(skill.get("implemented", true)), "%s/%s placeholder must declare implemented=false" % [producer_id, skill_id])
		_expect(not ready and progress < 1.0 - EPSILON, "%s/%s placeholder must stay explicitly unavailable" % [producer_id, skill_id])
		return
	if ready or progress >= 1.0 - EPSILON:
		_expect(allowed, "%s/%s reset is immediately ready without initial_ready_allowed=true" % [producer_id, skill_id])
	else:
		_expect(not allowed, "%s/%s declares an unused initial-ready exception" % [producer_id, skill_id])


func _advance_initial_contracts(
	path: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background,
	initial_skills: Dictionary
) -> void:
	var has_live_tick_contract := false
	for skill in initial_skills.values():
		if str((skill as Dictionary).get("cooldown_contract", "")) in ["time", "deferred_time"]:
			has_live_tick_contract = true
			break
	if has_live_tick_contract:
		_tick_state(path, state, context, background, 3)
	if initial_skills.has("hongryun_inferno"):
		state.register_fireball_hit_player()
	# Tetriser's resource gauge charges in the same live update already run for
	# its three time skills, so no second tick is added here (GRT-018).


func _verify_every_cast_reloads_and_ticks() -> void:
	for producer in _producers:
		var path := str(producer.get("path", ""))
		var producer_id := str(producer.get("id", ""))
		for skill_id_value in producer.get("skill_ids", []):
			var skill_id := str(skill_id_value)
			var state := _new_state(path)
			var context := _context_for_path(path)
			var background := FakeStage2Background.new()
			var initial_skill: Dictionary = _skill_map(path, state, context, background).get(skill_id, {})
			var contract := str(initial_skill.get("cooldown_contract", ""))
			if contract == "placeholder":
				_expect(not bool(initial_skill.get("implemented", true)), "%s/%s placeholder must remain explicit" % [producer_id, skill_id])
				continue
			var cast := _cast_skill(skill_id, state, context, background)
			_expect(cast, "%s/%s contract fixture must traverse its activation owner" % [producer_id, skill_id])
			if not cast:
				continue
			if skill_id == "psycho_ball":
				while state.is_psychoball_hitstop_active():
					state.update(0.05, context, {})
			var cast_skill: Dictionary = _skill_map(path, state, context, background).get(skill_id, {})
			_expect(not cast_skill.is_empty(), "%s/%s must remain published after cast" % [producer_id, skill_id])
			if skill_id == "spider_rage":
				_expect(str(cast_skill.get("status", "")) == "casting", "%s/%s score latch must publish casting" % [producer_id, skill_id])
				continue
			if skill_id == "friend_moles":
				state._stop_friend_moles()
				cast_skill = _skill_map(path, state, context, background).get(skill_id, {})
			if skill_id == "speed_defense":
				state.update(Stage2BossState.SPEED_DEFENSE_DURATION_SEC, context, {"stage_background": background})
				cast_skill = _skill_map(path, state, context, background).get(skill_id, {})
			var reloaded_remaining := float(cast_skill.get("cooldown_remaining", 0.0))
			_expect(reloaded_remaining > EPSILON, "%s/%s cast must reload a positive cooldown/resource" % [producer_id, skill_id])
			if skill_id == "hongryun_inferno":
				# The resource cannot recharge while Inferno owns the ball. End the
				# live cast through its production cleanup, then measure the next hit.
				state.resolve_inferno_player_miss(Vector2.ZERO, {})
				state.register_fireball_hit_player()
				_assert_remaining_drop(path, state, context, background, skill_id, reloaded_remaining, 1.0, producer_id)
				continue
			if skill_id == "stage6_super":
				state.update(0.05, context, {})
				_assert_remaining_drop(path, state, context, background, skill_id, reloaded_remaining, 1.25, producer_id)
				continue
			if skill_id == "illusion_ripple":
				state.illusion_active = false
			_advance_after_cast(path, state, context, background)
			var expected_drop := 1.0 / 72.0 if contract == "event_cycle" else _expected_time_drop(path)
			_assert_remaining_drop(path, state, context, background, skill_id, reloaded_remaining, expected_drop, producer_id)


func _assert_remaining_drop(
	path: String,
	state: Object,
	context: Dictionary,
	background: FakeStage2Background,
	skill_id: String,
	before: float,
	expected_drop: float,
	producer_id: String
) -> void:
	var after_skill: Dictionary = _skill_map(path, state, context, background).get(skill_id, {})
	var after := float(after_skill.get("cooldown_remaining", before))
	_expect(
		absf((before - after) - expected_drop) <= 0.001,
		"%s/%s cooldown must advance exactly once after cast (expected drop %.6f, got %.6f)"
		% [producer_id, skill_id, expected_drop, before - after]
	)


func _cast_skill(skill_id: String, state: Object, context: Dictionary, background: FakeStage2Background) -> bool:
	if skill_id in ["whip", "fan_wind", "arrest_rope"]:
		var runtime: Dictionary = state._get_runtime(skill_id)
		runtime["timer"] = float(runtime.get("duration", 1.0))
		runtime["ready"] = true
		runtime["status"] = "ready"
		state.skill_runtime[skill_id] = runtime
		return bool(state.consume_on_hit(skill_id, context, {}))
	if skill_id in ["spinning_top", "fan_throw", "patrol_guards"]:
		var runtime: Dictionary = state._get_runtime(skill_id)
		runtime["timer"] = float(runtime.get("duration", 1.0))
		runtime["ready"] = true
		runtime["status"] = "ready"
		state.skill_runtime[skill_id] = runtime
		var auto_skill := FakeStage1AutoSkill.new()
		auto_skill.block_activation = OS.get_environment(AUTO_TRIGGER_BLOCK_FIXTURE_ENV) == "1"
		var dep_key := str({
			"spinning_top": "stage1_dalji_spinning_top_skill_state",
			"fan_throw": "stage1_gaksital_fan_throw_skill_state",
			"patrol_guards": "stage1_pododaejang_patrol_guards_skill_state",
		}.get(skill_id, ""))
		state.update(0.0, context, {dep_key: auto_skill})
		return auto_skill.active
	match skill_id:
		"jungle_quake":
			state.quake_cooldown = 0.0
			return bool(state._activate_quake_from_cooldown(context, {}, background))
		"water_cannon":
			state.water_cannon_delay = 0.0
			return bool(state._update_water_cannon_schedule(context, {}, background))
		"speed_defense":
			state._activate_speed_defense(380.0, {}, context)
			return state.speed_defense_active
		"tunnel_raid":
			state._activate_tunnel(context, {})
			return state.tunnel_active
		"spinning_claw":
			state.boss_special_gauge = Stage2MolewangState.SPINNING_CLAW_COST
			state.spinning_claw_cooldown = 0.0
			var result: Dictionary = state.register_boss_hit(Vector2(2.0, 8.0), context, {})
			return bool(result.get("molewang_spinning_claw_triggered", false))
		"friend_moles":
			state.handle_score_event("player", {"player_score": 4}, {})
			state.reset_round()
			# Round transition starts the preserved 40-second event cycle. Move
			# that test-only clock to expiry so the activation owner can reload it.
			state.friend_moles_cooldown_ticks_remaining = 0
			state.update(0.0, context, {})
			return state.friend_moles_active
		"web_trap":
			state._activate_web_trap(context, {})
			return not state.web_trap_projectile.is_empty()
		"web_rescue":
			state.boss_special_gauge = Stage2ArachneState.WEB_RESCUE_COST
			state.web_rescue_cooldown = 0.0
			context["ball_pos"] = Vector2(380.0, 0.0)
			context["ball_vel"] = Vector2(0.0, -8.0)
			state.update(0.0, context, {})
			return state.web_rescue_active
		"spider_rage":
			state.handle_score_event("player", {"player_score": 4}, {})
			state.reset_round()
			return state.rage_active
		"tear_shower":
			state.get("_tear_shower_state").activate(context, {})
			return true
		"curse_chest":
			state.get("_curse_chest_state").activate({})
			return true
		"psycho_ball":
			state.get("_psychoball_state").activate(context)
			return true
		"cotton_throw":
			state._activate_cotton_throw({})
			return true
		"cotton_bomb":
			state._activate_cotton_bomb({})
			return true
		"deadly_hug":
			state._activate_deadly_hug(context, {})
			return true
		"heart_beam":
			state._activate_heart_beam(context, {})
			return true
		"mirror_world":
			state._activate_mirror({})
			return true
		"size_shift":
			state._activate_size_shift(context, {}, 2.0)
			return true
		"rabbit_projectile":
			state._activate_rabbits()
			return true
		"magnetic_field":
			return bool(state.force_activate_magnetic(context, {}))
		"meditation":
			return bool(state.force_activate_meditation(context, {}))
		"illusion_ripple":
			return bool(state.force_activate_illusion())
		"hongryun_fireball":
			state.fireball_cooldown = 0.0
			state.update(0.05, context, {})
			return state.fireball_cooldown > 0.0
		"hongryun_inferno":
			state.debug_force_inferno_ready()
			var result: Dictionary = state.register_boss_paddle_contact(Vector2(0.0, -8.0), {}, context)
			return bool(result.get("stage5_hongryun_inferno_started", false))
		"stage6_tetro_drop":
			state.debug_set_gauge(30.0)
			state.debug_set_spawn_timer(0.0)
			state.update(0.05, context, {})
			return state.debug_get_tetromino_count() > 0
		"stage6_guard":
			state.debug_set_gauge(100.0)
			# WIP refactor moved the timer into the guard owner module. set() on the
			# aggregate is a silent no-op, so reach the real owner (GRT-051 sibling).
			state.get("_guard_state").set("_timer_sec", 0.0)
			state.update(0.05, context, {})
			return state.debug_get_guard_count() > 0
		"stage6_wall":
			state.debug_set_gauge(50.0)
			state.get("_wall_state").set("_timer_sec", 0.0)
			state.update(0.05, context, {})
			return state.debug_get_wall_piece_count() > 0
		"stage6_super":
			state.debug_set_gauge(500.0)
			state.update(0.05, context, {})
			if not state.debug_is_super_active():
				return false
			state.debug_set_gauge(0.0)
			state.update(0.05, context, {})
			return not state.debug_is_super_active()
		"stage7_clone":
			state.debug_set_gauge(100.0)
			state.debug_set_clone_cooldown_remaining(0.0)
			if not state.debug_start_clone_cast(context, false, true):
				return false
			for _tick in range(5):
				state.update(0.1, context, {})
			return float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", 0.0)) > 0.0
		"stage7_shuriken":
			state.debug_set_gauge(100.0)
			state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
			state.update(1.0 / 60.0, context, {})
			for _tick in range(18):
				state.update(1.0 / 60.0, context, {})
			return float(state.debug_get_shuriken_snapshot().get("cooldown_remaining_sec", 0.0)) >= 8.0
		"stage7_cloud":
			state.debug_set_gauge(120.0)
			state.debug_set_cloud_cooldown_remaining(0.0, 15.0)
			return bool(state.debug_start_cloud(context, {}, false, true))
		"stage7_superspeed":
			state.debug_set_shuriken_cooldown_remaining(999.0, 999.0)
			state.debug_set_superspeed_cooldown_remaining(0.0)
			state.debug_set_gauge(250.0)
			if not state.debug_start_superspeed(context):
				return false
			# Cross the 10-second duration by one clamped tick so a floating
			# endpoint residue cannot hide the production 50-second reload.
			for _tick in range(101):
				state.update(0.1, context, {})
			return float(state.debug_get_superspeed_snapshot().get("cooldown_remaining_sec", 0.0)) > 0.0
	return false


func _expected_trigger_type(skill_id: String) -> String:
	return (
		BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT
		if skill_id in ON_BOSS_HIT_SKILL_IDS
		else BossSkillTriggerClass.TRIGGER_INSTANT
	)


func _verify_production_update_owner() -> void:
	var controller := BattleEffectsUpdateController.new()
	for producer in _producers:
		var path := str(producer.get("path", ""))
		if int(producer.get("stage", 0)) != 1:
			continue
		var state := _new_state(path, false)
		var context := _context_for_path(path)
		var dep_key := _stage1_cooldown_dep_key(path)
		controller.update(1.0 / 60.0, context, {dep_key: state})
		var first_skill: Dictionary = state.skill_runtime.values()[0]
		_expect(absf(float(first_skill.get("timer", 0.0)) - 1.0) <= EPSILON, "%s production controller must tick exactly once" % producer.get("id", ""))

	for variant_id in ["molewang", "arachne"]:
		var state := Stage2BossVariantState.new()
		state.reset()
		var context := _base_context(2)
		context["stage_boss_variant"] = variant_id
		state.update(0.0, context, {})
		controller.update(0.05, context, {"stage2_boss_skill_state": state})
		var actual: float = float(state.molewang_state.tunnel_cooldown) if variant_id == "molewang" else float(state.arachne_state.web_trap_cooldown)
		var initial: float = Stage2MolewangState.TUNNEL_INITIAL_COOLDOWN_SEC if variant_id == "molewang" else Stage2ArachneState.WEB_TRAP_INITIAL_COOLDOWN_SEC
		_expect(absf(actual - initial + 0.05) <= EPSILON, "%s production controller must tick exactly once" % variant_id)

	for variant_id in ["teddy_bear", "alice"]:
		var state := Stage3BossVariantState.new()
		state.reset()
		var context := _base_context(3)
		context["stage_boss_variant"] = variant_id
		state.update(0.0, context, {})
		controller.update(0.05, context, {"stage3_boss_skill_state": state})
		var actual: float = float(state.teddy_bear_state.cotton_throw_cooldown) if variant_id == "teddy_bear" else float(state.alice_state.mirror_cooldown)
		var initial: float = Stage3TeddyBearState.COTTON_THROW_INITIAL_COOLDOWN_SEC if variant_id == "teddy_bear" else Stage3AliceState.MIRROR_INITIAL_COOLDOWN_SEC
		_expect(absf(actual - initial + 0.05) <= EPSILON, "%s production controller must tick exactly once" % variant_id)

	var stage4_path := _producer_path_for_stage(4)
	var stage4_state := _new_state(stage4_path, false)
	var stage4_map := Stage4MapState.new()
	var stage4_background := Stage4PillarBackground.new()
	controller.update(0.05, _base_context(4), {
		"stage_background": stage4_background,
		"stage4_map_state": stage4_map,
		"stage4_ponk_skill_state": stage4_state,
	})
	_expect(absf(float(stage4_state.magnetic_cooldown_seconds) - 24.95) <= EPSILON, "Stage 4 production background chain must tick Ponk exactly once")
	# The production background intentionally caches its dependency dictionary.
	# Break the test-only background -> deps -> background cycle before exit.
	stage4_background.reset()

	for stage in [5, 6, 7]:
		var path := _producer_path_for_stage(stage)
		var state := _new_state(path, false)
		var context := _base_context(stage)
		var before: float
		var skill_id: String
		var dep_key: String
		match stage:
			5:
				before = float(state.fireball_cooldown)
				skill_id = "hongryun_fireball"
				dep_key = "stage5_hongryun_state"
			6:
				before = float(_skill_map(path, state, context, FakeStage2Background.new())["stage6_tetro_drop"].get("cooldown_remaining", 0.0))
				skill_id = "stage6_tetro_drop"
				dep_key = "stage6_tetriser_state"
			7:
				# Score 4 starts Awakening and legitimately consumes this frame.
				# This owner-count probe needs an ordinary live combat frame.
				context["player_score"] = 0
				before = float(state.debug_get_clone_snapshot().get("cooldown_remaining_sec", 0.0))
				skill_id = "stage7_clone"
				dep_key = "stage7_akamu_state"
		controller.update(0.05, context, {dep_key: state})
		var after := float(_skill_map(path, state, context, FakeStage2Background.new())[skill_id].get("cooldown_remaining", before))
		_expect(absf((before - after) - 0.05) <= EPSILON, "Stage %d production controller must tick exactly once" % stage)

	var controller_source := FileAccess.get_file_as_string("res://scripts/effects/battle_effects_update_controller.gd")
	for marker in [
		"stage5_hongryun_state.update(delta, context, effect_deps)",
		"stage6_tetriser_state.update(delta, context, effect_deps)",
		"stage7_akamu_state.update(delta, context, effect_deps)",
		"stage8_minotaur_state.update(delta, context, effect_deps)",
	]:
		_expect(_count_occurrences(controller_source, marker) == 1, "production update owner must contain exactly one call: %s" % marker)
	var background_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_pillar_background.gd")
	var map_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_map_state.gd")
	_expect(_count_occurrences(background_source, "map_state.update(delta, context, deps)") == 1, "Stage 4 background must tick map state exactly once")
	_expect(_count_occurrences(map_source, "ponk_skill_state.update(delta, event_context, deps)") == 1, "Stage 4 map must tick Ponk state exactly once")


func _tick_state(path: String, state: Object, context: Dictionary, background: FakeStage2Background, count: int) -> void:
	for _index in range(count):
		if int(context.get("current_stage", 0)) == 1:
			state.update(1.0, context, {})
		elif int(context.get("current_stage", 0)) == 2 and path.ends_with("stage2_boss_skill_state.gd"):
			state.update(0.05, context, {"stage_background": background})
		else:
			state.update(0.05, context, {})


func _advance_after_cast(path: String, state: Object, context: Dictionary, background: FakeStage2Background) -> void:
	_tick_state(path, state, context, background, 1)


func _expected_time_drop(path: String) -> float:
	return 1.0 / 60.0 if _stage_from_path(path) == 1 else 0.05


func _skill_map(path: String, state: Object, context: Dictionary, background: FakeStage2Background) -> Dictionary:
	var argument_count := _method_argument_count(state, "get_hud_context")
	var args: Array = []
	if argument_count == 1:
		args = [{}]
	elif argument_count >= 2:
		args = [background, context]
	var hud_value: Variant = state.callv("get_hud_context", args)
	var hud_context: Dictionary = hud_value if hud_value is Dictionary else {}
	var result := {}
	for key_value in hud_context.keys():
		var key := str(key_value)
		if not key.ends_with("_boss_skill_hud_skills"):
			continue
		for value in hud_context.get(key, []):
			if value is Dictionary:
				var skill: Dictionary = value
				result[str(skill.get("id", ""))] = skill
	return result


func _new_state(path: String, prepare_first_publication: bool = true) -> Object:
	var script_value: Variant = load(path)
	if not (script_value is Script) or not (script_value as Script).can_instantiate():
		_expect(false, "could not instantiate discovered HUD producer: %s" % path)
		return null
	var state: Object = (script_value as Script).new()
	if state.has_method("reset"):
		state.call("reset")
	if prepare_first_publication and path.ends_with("stage7_akamu_state.gd"):
		# Superspeed is absent while locked. Its first player-visible publication
		# is Awakening completion, which arms the production 50-second cooldown.
		state.debug_force_complete_awakening()
	return state


func _context_for_path(path: String) -> Dictionary:
	var stage := _stage_from_path(path)
	var context := _base_context(stage)
	if stage == 1:
		if path.contains("gaksital"):
			context["stage1_boss_variant"] = "gaksi"
		elif path.contains("pododaejang"):
			context["stage1_boss_variant"] = "podo"
		else:
			context["stage1_boss_variant"] = "dalji"
	elif stage == 2:
		if path.contains("molewang"):
			context["stage_boss_variant"] = "molewang"
		elif path.contains("arachne"):
			context["stage_boss_variant"] = "arachne"
		else:
			context["stage_boss_variant"] = "cheongringwi"
	elif stage == 3:
		if path.contains("teddy_bear"):
			context["stage_boss_variant"] = "teddy_bear"
		elif path.contains("alice"):
			context["stage_boss_variant"] = "alice"
		else:
			context["stage_boss_variant"] = "yeonmyo"
	return context


func _base_context(stage: int) -> Dictionary:
	return {
		"current_stage": stage,
		"stage_boss_variant": "",
		"ball_active": true,
		"waiting_for_serve": false,
		"player_score": 4,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 350.0),
		"ball_vel": Vector2(2.0, 8.0),
		"ball_size": 28.6,
		"dash_snapshot": {"active": false},
	}


func _stage_from_path(path: String) -> int:
	# Do not cap discovery at today's highest stage. A future stage directory
	# must enter the seal automatically and fail on missing metadata/fixtures.
	for segment_value in path.split("/"):
		var segment := str(segment_value)
		if not segment.begins_with("stage"):
			continue
		var suffix := segment.trim_prefix("stage")
		if suffix.is_valid_int():
			return int(suffix)
	return 0


func _method_argument_count(state: Object, method_name: String) -> int:
	for method_value in state.get_method_list():
		var method: Dictionary = method_value
		if str(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return 0


func _producer_path_for_stage(stage: int) -> String:
	for producer in _producers:
		if int(producer.get("stage", 0)) == stage:
			return str(producer.get("path", ""))
	return ""


func _stage1_cooldown_dep_key(path: String) -> String:
	if path.contains("gaksital"):
		return "stage1_gaksital_boss_skill_cooldown_state"
	if path.contains("pododaejang"):
		return "stage1_pododaejang_boss_skill_cooldown_state"
	return "stage1_dalji_boss_skill_cooldown_state"


func _progress_map(skills: Dictionary) -> Dictionary:
	var result := {}
	for skill_id in skills:
		result[skill_id] = float((skills[skill_id] as Dictionary).get("progress", -1.0))
	return result


func _count_occurrences(source: String, marker: String) -> int:
	var count := 0
	var offset := 0
	while true:
		var found := source.find(marker, offset)
		if found < 0:
			return count
		count += 1
		offset = found + marker.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
