extends RefCounted

## Owns stage BGM runtime selection and playback state: priming, restart/stop,
## shared mute persistence/resume, current and muted track names, remembered
## prime gains, and Stage 1/2 RNG. Catalog metadata, player creation/looping,
## bus policy, and event timing remain outside this controller.

const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")

const FIXED_STAGE_BGM_IDS := {
	3: "stage3",
	4: "stage4",
	5: "stage5",
	6: "stage6",
	7: "stage7",
	# Python Stage 9 Minotaur has no dedicated track and explicitly reuses the
	# Stage 4 primary BGM. Godot maps that encounter to Stage 8.
	8: "stage4",
}

var _current_bgm_name := ""
var _primed_bgm_volumes: Dictionary = {}
var _bgm_muted := false
var _muted_bgm_name := ""
var _stage1_bgm_rng := RandomNumberGenerator.new()
var _stage1_bgm_rng_ready := false
var _stage2_bgm_rng := RandomNumberGenerator.new()
var _stage2_bgm_rng_ready := false


func play_stage4_phase2_bgm(ensure_player: Callable, get_player: Callable) -> bool:
	return play_bgm("stage4_phase2", ensure_player, get_player)


func play_stage_bgm(
	stage: int,
	catalog: Object,
	ensure_player: Callable,
	get_player: Callable
) -> bool:
	var bgm_id := _get_stage_primary_bgm_id(stage, catalog, ensure_player, get_player)
	if bgm_id.is_empty():
		stop_bgm(get_player)
		return false
	return play_bgm(bgm_id, ensure_player, get_player)


func prime_stage_bgm(
	stage: int,
	catalog: Object,
	ensure_player: Callable,
	get_player: Callable
) -> bool:
	if stage == 4:
		var stage4_ready := prime_bgm("stage4", ensure_player)
		var phase2_ready := prime_bgm("stage4_phase2", ensure_player)
		return stage4_ready or phase2_ready
	var bgm_id := _get_stage_primary_bgm_id(stage, catalog, ensure_player, get_player)
	if bgm_id.is_empty():
		return false
	return prime_bgm(bgm_id, ensure_player)


func prime_bgm(bgm_name: String, ensure_player: Callable) -> bool:
	var player := _call_player(ensure_player, bgm_name)
	if player == null or player.stream == null:
		return false
	if _bgm_muted:
		_current_bgm_name = bgm_name
		_muted_bgm_name = bgm_name
		return true
	if player.playing:
		return true
	if not _primed_bgm_volumes.has(bgm_name):
		_primed_bgm_volumes[bgm_name] = player.volume_db
	player.volume_db = -80.0
	player.pitch_scale = 1.0
	player.play()
	_current_bgm_name = bgm_name
	return true


func play_bgm(bgm_name: String, ensure_player: Callable, get_player: Callable) -> bool:
	var player := _call_player(ensure_player, bgm_name)
	if player == null or player.stream == null:
		return false
	var target_volume_db := player.volume_db
	if _primed_bgm_volumes.has(bgm_name):
		target_volume_db = float(_primed_bgm_volumes[bgm_name])
	if _bgm_muted:
		if player.playing:
			player.stop()
		player.volume_db = target_volume_db
		_current_bgm_name = bgm_name
		_muted_bgm_name = bgm_name
		_primed_bgm_volumes.erase(bgm_name)
		return true
	if _current_bgm_name == bgm_name and player.playing:
		player.seek(0.0)
		player.volume_db = target_volume_db
		_primed_bgm_volumes.erase(bgm_name)
		return true
	stop_bgm(get_player)
	player.volume_db = target_volume_db
	player.pitch_scale = 1.0
	player.play()
	_current_bgm_name = bgm_name
	_primed_bgm_volumes.erase(bgm_name)
	return true


func stop_bgm(get_player: Callable) -> void:
	var player := _call_player(get_player, _current_bgm_name)
	if player != null and player.playing:
		player.stop()
	if _primed_bgm_volumes.has(_current_bgm_name):
		if player != null:
			player.volume_db = float(_primed_bgm_volumes[_current_bgm_name])
		_primed_bgm_volumes.erase(_current_bgm_name)
	_current_bgm_name = ""
	_muted_bgm_name = ""


func toggle_bgm(
	owner_node: Node,
	ensure_player: Callable,
	get_player: Callable
) -> bool:
	return set_bgm_muted(not _bgm_muted, owner_node, ensure_player, get_player)


func set_bgm_muted(
	muted: bool,
	owner_node: Node,
	ensure_player: Callable,
	get_player: Callable
) -> bool:
	var tree := get_owner_tree(owner_node)
	if _bgm_muted == muted:
		BgmMuteState.set_muted(tree, _bgm_muted)
		return _bgm_muted
	_bgm_muted = BgmMuteState.set_muted(tree, muted)
	if _bgm_muted:
		_muted_bgm_name = _current_bgm_name
		var muted_player := _call_player(get_player, _current_bgm_name)
		if muted_player != null and muted_player.playing:
			muted_player.stop()
		if _primed_bgm_volumes.has(_current_bgm_name):
			if muted_player != null:
				muted_player.volume_db = float(_primed_bgm_volumes[_current_bgm_name])
			_primed_bgm_volumes.erase(_current_bgm_name)
		return true

	var target_bgm_name := _muted_bgm_name
	if target_bgm_name.is_empty():
		target_bgm_name = _current_bgm_name
	_muted_bgm_name = ""
	if not target_bgm_name.is_empty():
		_current_bgm_name = ""
		play_bgm(target_bgm_name, ensure_player, get_player)
	return false


func restore_bgm_muted(owner_node: Node) -> void:
	_bgm_muted = BgmMuteState.is_muted(get_owner_tree(owner_node))


func get_owner_tree(owner_node: Node) -> SceneTree:
	if owner_node != null and owner_node.is_inside_tree():
		return owner_node.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null


func select_stage_bgm_name(
	stage: int,
	catalog: Object,
	ensure_player: Callable,
	get_player: Callable
) -> String:
	var pool := _get_stage_pool(stage, catalog)
	var fallback := "stage1" if stage == 1 else "stage2"
	if pool.has(_current_bgm_name):
		var current_player := _call_player(get_player, _current_bgm_name)
		if _bgm_muted or (current_player != null and current_player.playing):
			return _current_bgm_name
	var candidates := get_stage_bgm_candidates(stage, catalog, ensure_player)
	if candidates.is_empty():
		return fallback
	if candidates.size() == 1:
		return candidates[0]
	if stage == 1:
		if not _stage1_bgm_rng_ready:
			_stage1_bgm_rng.randomize()
			_stage1_bgm_rng_ready = true
		return candidates[_stage1_bgm_rng.randi_range(0, candidates.size() - 1)]
	if not _stage2_bgm_rng_ready:
		_stage2_bgm_rng.randomize()
		_stage2_bgm_rng_ready = true
	return candidates[_stage2_bgm_rng.randi_range(0, candidates.size() - 1)]


func get_stage_bgm_candidates(stage: int, catalog: Object, ensure_player: Callable) -> Array[String]:
	var candidates: Array[String] = []
	for bgm_name: String in _get_stage_pool(stage, catalog):
		var player := _call_player(ensure_player, bgm_name)
		if player != null and player.stream != null:
			candidates.append(bgm_name)
	return candidates


func get_current_bgm_name() -> String:
	return _current_bgm_name


func set_current_bgm_name(value: String) -> void:
	_current_bgm_name = value


func get_primed_bgm_volumes() -> Dictionary:
	return _primed_bgm_volumes


func set_primed_bgm_volumes(value: Dictionary) -> void:
	_primed_bgm_volumes = value


func is_bgm_muted() -> bool:
	return _bgm_muted


func set_bgm_muted_state(value: bool) -> void:
	_bgm_muted = value


func get_muted_bgm_name() -> String:
	return _muted_bgm_name


func set_muted_bgm_name(value: String) -> void:
	_muted_bgm_name = value


func get_stage1_bgm_rng() -> RandomNumberGenerator:
	return _stage1_bgm_rng


func set_stage1_bgm_rng(value: RandomNumberGenerator) -> void:
	_stage1_bgm_rng = value


func is_stage1_bgm_rng_ready() -> bool:
	return _stage1_bgm_rng_ready


func set_stage1_bgm_rng_ready(value: bool) -> void:
	_stage1_bgm_rng_ready = value


func get_stage2_bgm_rng() -> RandomNumberGenerator:
	return _stage2_bgm_rng


func set_stage2_bgm_rng(value: RandomNumberGenerator) -> void:
	_stage2_bgm_rng = value


func is_stage2_bgm_rng_ready() -> bool:
	return _stage2_bgm_rng_ready


func set_stage2_bgm_rng_ready(value: bool) -> void:
	_stage2_bgm_rng_ready = value


func _get_stage_primary_bgm_id(
	stage: int,
	catalog: Object,
	ensure_player: Callable,
	get_player: Callable
) -> String:
	if stage == 1 or stage == 2:
		return select_stage_bgm_name(stage, catalog, ensure_player, get_player)
	return str(FIXED_STAGE_BGM_IDS.get(stage, ""))


func _get_stage_pool(stage: int, catalog: Object) -> Array[String]:
	if catalog == null or not catalog.has_method("get_stage_pool"):
		return []
	var values: Array = catalog.get_stage_pool(stage)
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


func _call_player(callback: Callable, bgm_name: String) -> AudioStreamPlayer:
	if not callback.is_valid():
		return null
	var value: Variant = callback.call(bgm_name)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null
