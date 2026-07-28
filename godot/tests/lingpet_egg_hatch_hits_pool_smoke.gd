extends SceneTree

const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var ball_active := true
	var ball_pos := Vector2(200.0, 200.0)
	var ball_vel := Vector2(4.0, -6.0)
	var ball_size := 28.6
	var ball_serve_origin := "boss"
	var player_pos := Vector2(300.0, 670.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


func _init() -> void:
	_verify_pool_and_deterministic_rng_for_both_paths()
	_verify_four_hit_progress_is_monotonic_and_not_front_loaded()
	_verify_runtime_uses_field_state_for_main_and_item_eggs()
	if _failures.is_empty():
		print("lingpet_egg_hatch_hits_pool_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_pool_and_deterministic_rng_for_both_paths() -> void:
	_expect(LingpetEggFieldState.HATCH_REQUIRED_HITS_POOL == [2, 3, 4], "hatch pool must be exactly [2, 3, 4]")
	var observed: Dictionary = {}
	for seed in range(1, 128):
		var main_rng := RandomNumberGenerator.new()
		var item_rng := RandomNumberGenerator.new()
		main_rng.seed = seed
		item_rng.seed = seed
		var main_state := LingpetEggFieldState.new()
		var item_state := LingpetEggFieldState.new()
		main_state.roll_required_hits(main_rng)
		item_state.roll_required_hits(item_rng)
		var main_hits := main_state.get_required_hits()
		var item_hits := item_state.get_required_hits()
		_expect(main_hits == item_hits, "main and item egg paths must consume deterministic RNG identically for seed %d" % seed)
		_expect(main_hits >= 2 and main_hits <= 4, "rolled hit count must stay inside 2..4")
		observed[main_hits] = true
	_expect(observed.size() == 3, "deterministic seed sweep should reach all three 2/3/4 outcomes")


func _verify_four_hit_progress_is_monotonic_and_not_front_loaded() -> void:
	var state := LingpetEggFieldState.new()
	state.pos = Vector2(200.0, 200.0)
	state.set_required_hits(4)
	var owner := FakeOwner.new()
	var ratios: Array[float] = []
	for hit_index in range(4):
		state.ball_was_inside = false
		state.hit_cooldown = 0.0
		owner.ball_pos = state.pos
		var result: Dictionary = state.resolve_ball_hit(owner, 4)
		_expect(bool(result.get("counted", false)), "each fresh contact should count exactly once")
		ratios.append(float(state.hatch_hits) / 4.0)
		_expect(bool(result.get("hatched", false)) == (hit_index == 3), "four-hit egg must hatch only on the fourth counted hit")
	_expect(ratios == [0.25, 0.5, 0.75, 1.0], "crack progress ratios must remain evenly distributed across four hits")


func _verify_runtime_uses_field_state_for_main_and_item_eggs() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(source.find("var _egg_state: Object = LingpetEggFieldState.new()") >= 0, "main field egg must use the shared hit-pool state")
	_expect(source.find("var _item_egg_state: Object = LingpetEggFieldState.new()") >= 0, "coexisting item/overflow egg must use the same hit-pool state")
	_expect(source.find("_egg_state.resolve_ball_hit") >= 0, "main egg hit path must resolve through the shared state")
	_expect(source.find("_item_egg_state,") >= 0 and source.find("advance_incubation_for_reveal") >= 0, "item egg hit path must resolve through the shared state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
