extends SceneTree

const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")
const Stage1BalloonStarpointState := preload("res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd")


class RuntimePerkStateStub:
	var collect_calls := 0
	var opens_choice := true

	func collect_star_points(
		_amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object = null,
		_registry: Object = null,
		_defer_choice_open: bool = false
	) -> bool:
		collect_calls += 1
		return opens_choice


class AudioStub:
	var collect_calls := 0

	func play_starpoint_collect() -> void:
		collect_calls += 1


func _init() -> void:
	seed(71031)
	_verify_owner_spawn_update_and_clear()
	_verify_modal_collection_preserves_tail()
	_verify_facade_compatibility_surface()
	_verify_source_ownership()
	print("stage1_balloon_starpoint_state_smoke: ok")
	quit(0)


func _verify_owner_spawn_update_and_clear() -> void:
	var state := Stage1BalloonStarpointState.new()
	state.configure_bounds(80.0, 680.0, 750.0)
	state.spawn_drop_at(Vector2(320.0, 300.0), {}, {}, false)
	_expect(state.drops.size() == 1, "owner should append one primary drop")
	_expect(state.particles.size() == Stage1BalloonStarpointState.PARTICLE_COUNT, "owner should append the Stage 1 spawn burst")
	_expect(state.has_runtime_state(), "owner should report live drop or particle state")

	var before_life: float = float(state.drops[0].get("life", 0.0))
	state.update_drops(1.0, _context(Vector2(-500.0, -500.0)), {})
	state.update_particles(1.0)
	_expect(float(state.drops[0].get("life", 0.0)) < before_life, "owner should advance drop lifetime")
	_expect(state.clear(), "clear should report that live state existed")
	_expect(state.drops.is_empty() and state.particles.is_empty(), "clear should empty both retained collections")
	_expect(not state.clear(), "a second clear should report no prior runtime state")


func _verify_modal_collection_preserves_tail() -> void:
	var state := Stage1BalloonStarpointState.new()
	state.configure_bounds(0.0, 760.0, 750.0)
	state.drops = [
		_make_drop(Vector2(100.0, 100.0)),
		_make_drop(Vector2(110.0, 100.0)),
	]
	var runtime_state := RuntimePerkStateStub.new()
	var audio := AudioStub.new()
	state.update_drops(0.0, _context(Vector2(92.0, 92.0)), {
		"runtime_perk_state": runtime_state,
		"audio": audio,
	})
	_expect(runtime_state.collect_calls == 1, "modal collection should stop after the first reward opens")
	_expect(audio.collect_calls == 1, "collection should emit exactly one audio cue")
	_expect(state.drops.size() == 1, "modal collection should preserve the unprocessed tail")
	_expect(_drop_pos(state.drops[0]) == Vector2(110.0, 100.0), "modal collection should preserve the correct tail drop")


func _verify_facade_compatibility_surface() -> void:
	var event := Stage1BalloonEvent.new()
	event.starpoint_drops = [_make_drop(Vector2(200.0, 220.0))]
	event.starpoint_particles = [{"pos": Vector2(201.0, 221.0), "life": 10.0}]
	_expect(event.starpoint_drops.size() == 1, "facade drop property should route to the retained owner")
	_expect(event.starpoint_particles.size() == 1, "facade particle property should route to the retained owner")
	event._update_starpoint_drops(0.0, _context(Vector2(-500.0, -500.0)), {})
	_expect(event.starpoint_drops.size() == 1, "legacy update facade should still advance owner state")
	event.reset()
	_expect(event.starpoint_drops.is_empty() and event.starpoint_particles.is_empty(), "facade reset should clear the retained owner")


func _verify_source_ownership() -> void:
	var facade_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd")
	_expect(facade_source.contains("Stage1BalloonStarpointState"), "balloon facade should preload the starpoint owner")
	_expect(facade_source.contains("var starpoint_state: Object = Stage1BalloonStarpointState.new()"), "balloon facade should retain one starpoint owner")
	_expect(not facade_source.contains("var starpoint_drops: Array[Dictionary] = []"), "balloon facade should not retain a mirrored drop array")
	_expect(not facade_source.contains("var starpoint_particles: Array[Dictionary] = []"), "balloon facade should not retain a mirrored particle array")
	_expect(_method_source(facade_source, "_spawn_starpoint_drop_at").contains("starpoint_state.spawn_drop_at"), "spawn compatibility method should delegate")
	_expect(_method_source(facade_source, "_update_starpoint_drops").contains("starpoint_state.update_drops"), "drop update compatibility method should delegate")
	_expect(_method_source(facade_source, "_spawn_starpoint_particles").contains("starpoint_state.spawn_particles"), "particle spawn compatibility method should delegate")
	_expect(_method_source(facade_source, "_update_starpoint_particles").contains("starpoint_state.update_particles"), "particle update compatibility method should delegate")
	_expect(owner_source.contains("StarpointCollectionCompaction.finish_in_place"), "owner should preserve modal-safe in-place compaction")
	_expect(owner_source.contains("LingpetStarlightTrackingBridge.update_drop"), "owner should retain Starlight Tracking delivery")
	_expect(owner_source.contains("StarpointDowsingAttraction.apply_to_drop"), "owner should retain Dowsing attraction")


func _context(player_pos: Vector2) -> Dictionary:
	return {
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"player_pos": player_pos,
		"player_paddle_size": Vector2(32.0, 32.0),
		"selected_character_type": "smasher",
	}


func _make_drop(pos: Vector2) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"size": Stage1BalloonStarpointState.DROP_SIZE,
		"rotation": 0.0,
		"rotation_speed": 0.0,
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": Stage1BalloonStarpointState.DROP_LIFETIME,
		"float_timer": 0.0,
	}


func _drop_pos(drop: Dictionary) -> Vector2:
	var value: Variant = drop.get("pos", Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
