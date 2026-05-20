extends RefCounted

const StageBallSpawnIntroBeginLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_begin_lifecycle.gd")
const StageBallSpawnIntroFinishLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_finish_lifecycle.gd")
const StageBallSpawnIntroInitialEntityLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_initial_entity_lifecycle.gd")
const StageBallSpawnIntroResetLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_reset_lifecycle.gd")
const StageBallSpawnIntroUpdateLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_update_lifecycle.gd")

var begin_lifecycle: Object = StageBallSpawnIntroBeginLifecycle.new()
var finish_lifecycle: Object = StageBallSpawnIntroFinishLifecycle.new()
var initial_entity_lifecycle: Object = StageBallSpawnIntroInitialEntityLifecycle.new()
var reset_lifecycle: Object = StageBallSpawnIntroResetLifecycle.new()
var update_lifecycle: Object = StageBallSpawnIntroUpdateLifecycle.new()


func begin_intro(intro: Object, owner: Object, registry: Object, config: Dictionary) -> bool:
	return begin_lifecycle.begin_intro(intro, owner, registry, config)


func update_intro(intro: Object, delta: float, owner: Object, registry: Object, config: Dictionary) -> void:
	update_lifecycle.update_intro(intro, delta, owner, registry, config)


func spawn_initial_entities(intro: Object, config: Dictionary) -> void:
	initial_entity_lifecycle.spawn_initial_entities(intro, config)


func finish(intro: Object, owner: Object, registry: Object, target_pos: Vector2) -> void:
	finish_lifecycle.finish_intro(intro, owner, registry, target_pos, reset_lifecycle)


func reset_state(intro: Object) -> void:
	reset_lifecycle.reset_state(intro)
