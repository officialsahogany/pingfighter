extends RefCounted

const PlayerActorAnimationState := preload("res://scripts/characters/player_actor_animation_state.gd")
const BossActorAnimationState := preload("res://scripts/characters/boss_actor_animation_state.gd")

const PLAYER_HIT_ANIM_DURATION := 0.36
const BOSS_HIT_ANIM_DURATION := 0.60

var player_state: Object = PlayerActorAnimationState.new()
var boss_state: Object = BossActorAnimationState.new()


func reset() -> void:
	player_state.reset()
	boss_state.reset()


func update(delta: float, context: Dictionary) -> void:
	player_state.update(delta, context)
	boss_state.update(delta, context)


func trigger_player_hit(hit_pos: float, has_hit_texture: bool, hit_duration: float = PLAYER_HIT_ANIM_DURATION) -> void:
	player_state.trigger_hit(hit_pos, has_hit_texture, hit_duration)


func trigger_boss_hit(boss_vel: float, has_hit_texture: bool, hit_duration: float = BOSS_HIT_ANIM_DURATION) -> void:
	boss_state.trigger_hit(boss_vel, has_hit_texture, hit_duration)


func get_player_hit_progress(hit_duration: float) -> float:
	return player_state.get_hit_progress(hit_duration)


func get_draw_context() -> Dictionary:
	var draw_context: Dictionary = player_state.get_draw_context()
	draw_context.merge(boss_state.get_draw_context(), true)
	return draw_context
