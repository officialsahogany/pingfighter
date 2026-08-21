extends SceneTree

const Stage2BossRageCoordinator := preload(
	"res://scripts/stages/stage2/stage2_boss_rage_coordinator.gd"
)
const Stage2BossRageState := preload(
	"res://scripts/stages/stage2/stage2_boss_rage_state.gd"
)
const Stage2QuakeRuntimeState := preload(
	"res://scripts/stages/stage2/stage2_quake_runtime_state.gd"
)
const Stage2RockLifecycleCoordinator := preload(
	"res://scripts/stages/stage2/stage2_rock_lifecycle_coordinator.gd"
)
const Stage2RockVisualFactory := preload(
	"res://scripts/stages/stage2/stage2_rock_visual_factory.gd"
)

const EXPECTED_LEG_COUNT := 8

var _failures: Array[String] = []
var _leg_count := 0


class FakeRageState:
	extends RefCounted

	var crisis_triggered := false
	var boss_rage_pending := false
	var boss_rage_active := false
	var ai_mode := "champion"

	func reset() -> void:
		crisis_triggered = false
		boss_rage_pending = false
		boss_rage_active = false
		ai_mode = "champion"

	func reserve_crisis(context: Dictionary, crisis_player_score: int) -> bool:
		var reservation := Stage2BossRageState.get_crisis_reservation(
			context,
			crisis_triggered,
			boss_rage_pending,
			boss_rage_active,
			crisis_player_score
		)
		if not bool(reservation.get("triggered", false)):
			return false
		crisis_triggered = true
		boss_rage_pending = true
		ai_mode = str(reservation.get("ai_mode", "champion"))
		return true

	func start() -> bool:
		if not boss_rage_pending:
			return false
		boss_rage_pending = false
		boss_rage_active = true
		return true

	func update(
		_delta: float,
		_stomp_interval_sec: float,
		_buildup_sec: float,
		_final_stomp_sec: float,
		_total_sec: float,
		_max_stomp_count: int
	) -> Dictionary:
		var final_stomp := boss_rage_active
		boss_rage_active = false
		return {
			"stomp_steps": [],
			"final_stomp": final_stomp,
			"finished": final_stomp,
		}


class FakeRockState:
	extends RefCounted

	var rocks: Array = []
	var next_id := 1

	func claim_next_id() -> int:
		var claimed := next_id
		next_id += 1
		return claimed

	func append_rock(rock: Dictionary) -> void:
		rocks.append(rock)

	func append_rocks(next_rocks: Array) -> void:
		rocks.append_array(next_rocks)


class FakeStage2BossSkillState:
	extends RefCounted

	var water_cannon_defer_count := 0

	func defer_water_cannon_after_rock_spawn() -> void:
		water_cannon_defer_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_variant_payload("molewang", "champion", 0)
	_verify_variant_payload("arachne", "champion", 0)
	_verify_variant_payload("cheongringwi", "champion", 3)
	_verify_variant_payload("cheongringwi", "mythic", 5)
	_verify_non_trigger_score(5)
	_verify_non_trigger_score(7)
	_verify_production_owner_chain()
	_verify_water_cannon_sibling_owner()
	_expect(
		_leg_count == EXPECTED_LEG_COUNT,
		"fixture leg count must stay synchronized"
	)
	if _failures.is_empty():
		print("stage2_variant_crisis_rockfall_smoke: ok PASS=%d" % _leg_count)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_variant_payload(variant_id: String, ai_mode: String, expected_count: int) -> void:
	_leg_count += 1
	var fixture := _build_fixture()
	var coordinator: Object = fixture.get("coordinator")
	var rock_state: Object = fixture.get("rock_state")
	var context := {
		"current_stage": 2,
		"stage_boss_variant": variant_id,
		"player_score": Stage2BossRageCoordinator.CRISIS_PLAYER_SCORE,
		"boss_score": 2,
		"ai_mode": ai_mode,
	}
	var reserved := bool(coordinator.reserve_crisis(context))
	if reserved:
		_expect(bool(coordinator.start({})), "%s crisis reservation must start" % variant_id)
		coordinator.update(2.0, {})
	_expect(
		rock_state.rocks.size() == expected_count,
		"%s %s crisis must emit %d actual rock payloads, got %d" % [
			variant_id,
			ai_mode,
			expected_count,
			rock_state.rocks.size(),
		]
	)


func _verify_non_trigger_score(player_score: int) -> void:
	_leg_count += 1
	var fixture := _build_fixture()
	var coordinator: Object = fixture.get("coordinator")
	var rock_state: Object = fixture.get("rock_state")
	var reserved := bool(coordinator.reserve_crisis({
		"current_stage": 2,
		"stage_boss_variant": "cheongringwi",
		"player_score": player_score,
		"boss_score": 2,
		"ai_mode": "champion",
	}))
	_expect(not reserved, "Cheongringwi score %d must not reserve the six-point crisis" % player_score)
	_expect(rock_state.rocks.is_empty(), "non-trigger scores must keep the payload empty")


func _verify_production_owner_chain() -> void:
	_leg_count += 1
	var update_source := FileAccess.get_file_as_string(
		"res://scripts/effects/battle_effects_update_controller.gd"
	)
	var background_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage2/stage2_pillar_background.gd"
	)
	var rage_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage2/stage2_boss_rage_coordinator.gd"
	)
	_expect(
		update_source.contains("stage_background.update(delta, context, effect_deps)"),
		"battle effects update must tick the common Stage 2 background"
	)
	_expect(
		background_source.contains("boss_rage_coordinator.reserve_crisis(context)"),
		"Stage 2 background must delegate the derived crisis gate"
	)
	_expect(
		rage_source.contains("spawn_crisis_rock_wall(deps)"),
		"final stomp must delegate to the real crisis rock payload owner"
	)


func _verify_water_cannon_sibling_owner() -> void:
	_leg_count += 1
	var fixture := _build_fixture()
	var coordinator: Object = fixture.get("coordinator")
	var skill_state := FakeStage2BossSkillState.new()
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "cheongringwi",
		"player_score": Stage2BossRageCoordinator.CRISIS_PLAYER_SCORE,
		"boss_score": 2,
		"ai_mode": "champion",
	}
	_expect(bool(coordinator.reserve_crisis(context)), "sibling fixture must reserve crisis")
	_expect(bool(coordinator.start({})), "sibling fixture must start crisis")
	coordinator.update(2.0, {"stage2_boss_skill_state": skill_state})
	_expect(
		skill_state.water_cannon_defer_count == 1,
		"actual crisis payload emission must retain one water-cannon sibling deferral"
	)


func _build_fixture() -> Dictionary:
	var rage_state := FakeRageState.new()
	var rock_state := FakeRockState.new()
	var lifecycle := Stage2RockLifecycleCoordinator.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	lifecycle.configure(
		rock_state,
		null,
		null,
		null,
		null,
		rng,
		Stage2RockVisualFactory.new(),
		null
	)
	var quake_state := Stage2QuakeRuntimeState.new()
	var coordinator := Stage2BossRageCoordinator.new()
	coordinator.configure(
		rage_state,
		quake_state,
		lifecycle,
		null,
		0.5,
		1.0,
		0.25
	)
	return {
		"coordinator": coordinator,
		"rock_state": rock_state,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
