extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3KuromiFractureParticles := preload("res://scripts/stages/stage3/stage3_kuromi_fracture_particles.gd")

# 2026-07-31 7점제 재보정: 2/5(40%) -> 3/7(43%). 매치 대비 각성 시점 비중을
# 유지한다. 절대값이라 승리 점수를 올릴 때 같이 올리지 않으면 각성이 상대적으로
# 앞당겨져 각성 보스와 싸우는 구간만 길어진다.
const AWAKEN_SCORE := 3
const AWAKENING_SEC := 3.0

var kuromi_petrified := true
var kuromi_awakening := false
var kuromi_awakening_timer := 0.0
var kuromi_awakening_explosion_spawned := false
var kuromi_awakened := false

var _fracture: Stage3KuromiFractureParticles


func _init(shared_rng: RandomNumberGenerator) -> void:
	_fracture = Stage3KuromiFractureParticles.new(shared_rng)


func reset() -> void:
	kuromi_petrified = true
	kuromi_awakening = false
	kuromi_awakening_timer = 0.0
	kuromi_awakening_explosion_spawned = false
	kuromi_awakened = false
	_fracture.clear()


func reset_round_effects() -> void:
	_fracture.clear_pending()


func maybe_start(player_score: int, deps: Dictionary = {}) -> bool:
	if player_score < AWAKEN_SCORE:
		return false
	if not kuromi_petrified or kuromi_awakening or kuromi_awakened:
		return false
	kuromi_awakening = true
	kuromi_awakening_timer = AWAKENING_SEC
	kuromi_awakening_explosion_spawned = false
	_fracture.clear()
	_play_audio(deps, "play_stage3_kuromi_awake")
	return true


func update(delta: float, deps: Dictionary) -> void:
	_fracture.update(delta)
	if not kuromi_awakening:
		return
	kuromi_awakening_timer = max(0.0, kuromi_awakening_timer - delta)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		var progress: float = get_progress()
		feedback.max_screen_shake(0.10 + progress * 0.12, 7.0 + progress * 8.0)
	if not kuromi_awakening_explosion_spawned and kuromi_awakening_timer <= delta:
		_spawn_fragments()
		_play_audio(deps, "play_stage3_kuromi_stonebreak")
		if feedback != null and feedback.has_method("set_screen_shake"):
			feedback.set_screen_shake(0.35, 15.0)
	if kuromi_awakening_timer <= 0.0:
		kuromi_awakening = false
		kuromi_petrified = false
		kuromi_awakened = true


func is_active() -> bool:
	return kuromi_awakening


func force_awake() -> void:
	kuromi_petrified = false
	kuromi_awakening = false
	kuromi_awakening_timer = 0.0
	kuromi_awakening_explosion_spawned = true
	kuromi_awakened = true
	_fracture.clear_pending()


func get_progress() -> float:
	if not kuromi_awakening and kuromi_awakened:
		return 1.0
	return clamp(1.0 - kuromi_awakening_timer / AWAKENING_SEC, 0.0, 1.0)


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_kuromi_petrified": kuromi_petrified,
		"stage3_kuromi_awakening": kuromi_awakening,
		"stage3_kuromi_awakening_progress": get_progress(),
		"stage3_kuromi_awakening_timer": kuromi_awakening_timer,
		"stage3_kuromi_awakened": kuromi_awakened,
		"stage3_kuromi_crack_particles": StageActorDrawContextArrays.snapshot(_fracture.particles, copy_arrays, false),
		"stage3_kuromi_crack_particles_draw_order": StageActorDrawContextArrays.snapshot(_fracture.particles_draw_order, copy_arrays, false),
	}


func _spawn_fragments() -> void:
	if kuromi_awakening_explosion_spawned:
		return
	kuromi_awakening_explosion_spawned = true
	_fracture.spawn_explosion()


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)
