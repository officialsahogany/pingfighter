extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

const VIEW_SIZE := Vector2i(760, 750)
const SKELETON_SKILL_ID := "nekuring_skeleton_archer"
const BONE_SKILL_ID := "nekuring_bone_barrier"
const MILK_SKILL_ID := "milkring_milk_shot"
const STAR_SKILL_ID := "orosha_star_coil"

var _failures: Array[String] = []
var _host: Object = null
var _perf_logger: FakePerfLogger = null
var _probe: DrawPerfProbe = null


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := true
	var waiting_for_serve := false
	var ball_pos := Vector2(520.0, 300.0)
	var ball_vel := Vector2(0.0, -8.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 0.975
	var ball_min_boost := 0.70
	var lingpet_puppet_grab_active := false
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0


class FakeStatusEffectState:
	extends RefCounted

	func apply_status(_target: String, _status_id: String, _duration_frames: float, _data: Dictionary = {}, _source: String = "") -> Dictionary:
		return {}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []
	var counters: Dictionary = {}
	var _sample := 0

	func begin_sample() -> int:
		_sample += 1
		return _sample

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func record_counter_sample(label: String, value: float) -> void:
		counters[label] = value


class DrawPerfProbe:
	extends Node2D

	var host: Object = null
	var perf_logger: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if host != null:
			host.draw(self, Vector2.ZERO, perf_logger)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_host = LingpetSkillRuntimeHost.new()
	_perf_logger = FakePerfLogger.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({"status_effect_state": FakeStatusEffectState.new()})
	_setup_visible_skills(owner, registry)
	_probe = DrawPerfProbe.new()
	_probe.host = _host
	_probe.perf_logger = _perf_logger
	get_root().add_child(_probe)
	_probe.queue_redraw()
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	_verify_draw_labels_and_counters()
	if _failures.is_empty():
		print("lingpet_skill_draw_perf_label_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _setup_visible_skills(owner: FakeOwner, registry: FakeRegistry) -> void:
	_expect(_host.launch(
		SKELETON_SKILL_ID,
		Vector2(380.0, 680.0),
		owner,
		{"registry": registry, "spawn_x": 380.0, "spawn_y": 650.0, "arrow_cooldown": 99.0}
	), "Skeleton Archer fixture should launch")
	_host.set_bone_barrier_x_values_for_tests([320.0])
	_expect(_host.launch(BONE_SKILL_ID, Vector2(380.0, 680.0), owner, {"registry": registry, "barrier_x": 320.0}), "Bone Barrier fixture should launch")
	var milk_context := LingpetCatalog.get_active_skill("milkring", MILK_SKILL_ID, 5)
	milk_context["registry"] = registry
	milk_context["active_skill_id"] = MILK_SKILL_ID
	milk_context["active_skill_level"] = 5
	milk_context["companion_pos"] = Vector2(380.0, 640.0)
	milk_context["milk_shot_mega_roll"] = 0.90
	_expect(_host.launch(MILK_SKILL_ID, Vector2(380.0, 640.0), owner, milk_context), "Milk Shot fixture should launch")
	var star_context := _star_context(owner, 5)
	_expect(_host.launch(STAR_SKILL_ID, Vector2(380.0, 650.0), owner, star_context), "Star Coil fixture should launch")
	_host.update(1.0 / 60.0, owner, registry, STAR_SKILL_ID, star_context)


func _star_context(owner: FakeOwner, level: int) -> Dictionary:
	var skill: Dictionary = LingpetCatalog.get_active_skill("orosha", STAR_SKILL_ID, level)
	return {
		"companion_pos": Vector2(380.0, 650.0),
		"companion_radius": 32.0,
		"companion_visible": true,
		"active_skill_id": STAR_SKILL_ID,
		"active_skill_level": level,
		"slow_duration": float(skill.get("slow_duration", -1.0)),
		"slow_multiplier": float(skill.get("slow_multiplier", -1.0)),
		"ball_active": owner.ball_active,
		"ball_pos": owner.ball_pos,
		"ball_vel": owner.ball_vel,
		"boss_pos": owner.boss_pos,
		"boss_paddle_width": owner.boss_paddle_width,
		"boss_hitbox_height": owner.boss_hitbox_height,
	}


func _verify_draw_labels_and_counters() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "draw perf probe should receive a draw callback")
	var expected_labels := [
		"draw.lingpet.milk_shot",
		"draw.lingpet.skeleton_archer",
		"draw.lingpet.bone_barrier",
		"draw.lingpet.star_coil",
	]
	for label in expected_labels:
		_expect(_perf_logger.labels.has(label), "BattlePerf label should be recorded for %s" % label)
	var expected_counters := [
		"lingpet.milk_shot.projectiles",
		"lingpet.milk_shot.particles",
		"lingpet.skeleton_archer.archers",
		"lingpet.skeleton_archer.arrows",
		"lingpet.skeleton_archer.dying",
		"lingpet.skeleton_archer.particles",
		"lingpet.bone_barrier.barriers",
		"lingpet.bone_barrier.dying",
		"lingpet.bone_barrier.particles",
		"lingpet.star_coil.trail",
		"lingpet.star_coil.sparks",
	]
	for counter in expected_counters:
		_expect(_perf_logger.counters.has(counter), "BattlePerf counter should be recorded for %s" % counter)
	_expect(float(_perf_logger.counters.get("lingpet.bone_barrier.barriers", 0.0)) >= 1.0, "Bone Barrier counter should report live barriers")
	_expect(float(_perf_logger.counters.get("lingpet.milk_shot.projectiles", 0.0)) >= 1.0, "Milk Shot counter should report live projectiles")
	_expect(float(_perf_logger.counters.get("lingpet.star_coil.trail", 0.0)) >= 1.0, "Star Coil counter should report the launch trail")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
