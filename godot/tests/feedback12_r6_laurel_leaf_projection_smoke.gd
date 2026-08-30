extends SceneTree

# expect-zero-object-leaks
# Feedback12 R6 seal: gameplay keeps the authored 1/3/5 blocking leaves while
# the procedural draw projects the three Mugong ranks to 1/2/3 visible leaves.

const LaurelLeafShieldState := preload("res://scripts/characters/laurel_leaf_shield_state.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const BattleSceneRuntimePerkUpdateDriver := preload("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")

const STATE_PATH := "res://scripts/characters/laurel_leaf_shield_state.gd"
const PERK_ID := "perk_laurel_shield"
const FRAME_DELTA := 1.0 / 60.0
const RNG_SEED := 0x6A17E1
const OWNER_CENTER := Vector2(380.0, 700.0)
const PLAYER_SIZE := Vector2(155.0, 50.0)
const DISPLAY_ACTIVE_SEQUENCE := [3, 3, 2, 2, 1, 0]

const PROJECTION_CASES := [
	{"label": "rank 1", "rank": 1, "effective_bonus": 0, "logical": 1, "display": 1},
	{"label": "rank 2", "rank": 2, "effective_bonus": 0, "logical": 3, "display": 2},
	{"label": "rank 3", "rank": 3, "effective_bonus": 0, "logical": 5, "display": 3},
	{"label": "raw rank overflow", "rank": 4, "effective_bonus": 0, "logical": 6, "display": 3},
	{"label": "effective overflow", "rank": 3, "effective_bonus": 2, "logical": 7, "display": 3},
]

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(302.5, 675.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class FakeRuntimePerkState:
	extends RefCounted

	var logical_leaf_count := 0

	func get_laurel_leaf_count(_registry: Object = null) -> int:
		return logical_leaf_count


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object
	var laurel_leaf_shield_state: Object

	func _init(perk_state: Object, shield_state: Object) -> void:
		runtime_perk_state = perk_state
		laurel_leaf_shield_state = shield_state

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"laurel_leaf_shield_state":
				return laurel_leaf_shield_state
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_rank_projection_through_production_update()
	_verify_consumption_projection_and_shared_hit_positions()
	_verify_initial_projection_collision_classification()
	_verify_hidden_logical_leaf_cannot_block()
	_verify_stable_update_rng_and_allocation_seam()
	_verify_draw_projection_hot_path_contract()
	if _failures.is_empty():
		print("feedback12_r6_laurel_leaf_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_rank_projection_through_production_update() -> void:
	var effective_levels := RuntimePerkEffectiveLevels.new()
	var owner := FakeOwner.new()
	var runtime_state := FakeRuntimePerkState.new()
	var shield_state := LaurelLeafShieldState.new()
	var registry := FakeRegistry.new(runtime_state, shield_state)
	var update_driver := BattleSceneRuntimePerkUpdateDriver.new()
	var constants: Dictionary = (LaurelLeafShieldState as GDScript).get_script_constant_map()
	_expect(
		int(constants.get("MAX_DISPLAY_LEAF_COUNT", -1)) == 3,
		"Laurel presentation must declare a three-leaf display ceiling"
	)

	for case_data in PROJECTION_CASES:
		var spec: Dictionary = case_data
		var rank: int = int(spec.get("rank", 0))
		var effective_bonus: int = int(spec.get("effective_bonus", 0))
		var expected_logical: int = int(spec.get("logical", 0))
		var expected_display: int = int(spec.get("display", 0))
		var label: String = str(spec.get("label", "unnamed"))
		var logical_count: int = effective_levels.get_laurel_leaf_count(
			{PERK_ID: rank},
			effective_bonus,
			false
		)
		_expect(
			logical_count == expected_logical,
			"%s must preserve authored gameplay leaves: got %d expected %d" % [label, logical_count, expected_logical]
		)
		runtime_state.logical_leaf_count = logical_count
		update_driver.update_runtime_perk_resume(owner, registry, 0.0)
		var snapshot: Dictionary = shield_state.get_snapshot()
		_expect(int(snapshot.get("leaf_count", -1)) == expected_logical, "%s update path must retain logical leaf_count" % label)
		_expect(int(snapshot.get("active_leaf_count", -1)) == expected_logical, "%s must start with every logical blocking leaf active" % label)
		_expect(shield_state.leaves.size() == expected_logical, "%s collision storage must retain all logical leaves" % label)
		_expect(snapshot.has("display_leaf_count"), "%s snapshot must expose the production draw projection" % label)
		_expect(int(snapshot.get("display_leaf_count", -1)) == expected_display, "%s must project to %d visible leaves" % [label, expected_display])
		var getter_display := -1
		if shield_state.has_method("get_display_leaf_count"):
			getter_display = int(shield_state.call("get_display_leaf_count"))
		_expect(getter_display == expected_display, "%s draw getter must project to %d visible leaves" % [label, expected_display])


func _verify_consumption_projection_and_shared_hit_positions() -> void:
	var fixture := _make_rank_three_fixture()
	var shield_state: Object = fixture.get("shield_state")
	if not _expect_projection_surface(shield_state):
		return
	var constants: Dictionary = (LaurelLeafShieldState as GDScript).get_script_constant_map()
	var particle_count := int(constants.get("PARTICLE_COUNT", 15))
	var previous_mask := -1
	var previous_display_active := DISPLAY_ACTIVE_SEQUENCE[0]
	for remaining in range(5, -1, -1):
		var snapshot: Dictionary = shield_state.get_snapshot()
		var display_active := int(snapshot.get("display_active_leaf_count", -1))
		var display_mask := int(shield_state.call("get_display_leaf_mask"))
		_expect(
			int(snapshot.get("active_leaf_count", -1)) == remaining,
			"rank-3 consumption must retain %d logical blocking leaves" % remaining
		)
		_expect(
			display_active == int(DISPLAY_ACTIVE_SEQUENCE[5 - remaining]),
			"rank-3 remaining %d must project to %d displayed leaves" % [
				remaining,
				int(DISPLAY_ACTIVE_SEQUENCE[5 - remaining]),
			]
		)
		_expect(
			display_active <= previous_display_active,
			"displayed leaf count must decrease monotonically at remaining %d" % remaining
		)
		_expect(
			_count_set_bits(display_mask, shield_state.leaves.size()) == display_active,
			"display mask must contain exactly %d representatives at remaining %d" % [
				display_active,
				remaining,
			]
		)
		if previous_mask >= 0:
			_expect(
				display_mask != previous_mask,
				"each consumed logical leaf must immediately change the displayed subset at remaining %d" % remaining
			)
		previous_mask = display_mask
		previous_display_active = display_active
		if remaining <= 0:
			continue
		var logical_index := _first_set_bit(display_mask, shield_state.leaves.size())
		_expect(logical_index >= 0, "each positive remainder must expose a displayed logical leaf")
		if logical_index < 0:
			continue
		var leaf: Dictionary = shield_state.leaves[logical_index]
		shield_state.current_angle = -float(leaf.get("base_angle", 0.0))
		var displayed_position: Vector2 = shield_state.call("_get_leaf_position", leaf)
		var particles_before: int = shield_state.particles.size()
		var result: Dictionary = shield_state.resolve_ball_collision(
			_build_ball_scene(displayed_position),
			_build_collision_context(),
			{}
		)
		_expect(bool(result.get("laurel_leaf_hit", false)), "displayed leaf must block at remaining %d" % remaining)
		_expect(
			int(shield_state.get_snapshot().get("active_leaf_count", -1)) == remaining - 1,
			"displayed hit must consume exactly one logical leaf at remaining %d" % remaining
		)
		_expect(
			shield_state.particles.size() == particles_before + particle_count,
			"displayed hit must emit exactly one leaf-break particle batch"
		)
		for particle_index in range(particles_before, shield_state.particles.size()):
			var particle: Dictionary = shield_state.particles[particle_index]
			var particle_position: Vector2 = particle.get("position", Vector2.ZERO)
			_expect(
				particle_position.is_equal_approx(displayed_position),
				"leaf-break particle %d must originate at the displayed collision position" % particle_index
			)


func _verify_hidden_logical_leaf_cannot_block() -> void:
	var fixture := _make_rank_three_fixture()
	var shield_state: Object = fixture.get("shield_state")
	if not _expect_projection_surface(shield_state):
		return
	var display_mask := int(shield_state.call("get_display_leaf_mask"))
	var hidden_index := _first_clear_active_bit(
		display_mask,
		shield_state.leaves
	)
	_expect(hidden_index >= 0, "rank-3 projection must keep at least one logical reserve leaf hidden")
	if hidden_index < 0:
		return
	var hidden_leaf: Dictionary = shield_state.leaves[hidden_index]
	shield_state.current_angle = -float(hidden_leaf.get("base_angle", 0.0))
	var hidden_position: Vector2 = shield_state.call("_get_leaf_position", hidden_leaf)
	var result: Dictionary = shield_state.resolve_ball_collision(
		_build_ball_scene(hidden_position),
		_build_collision_context(),
		{}
	)
	_expect(result.is_empty(), "projected-out logical leaf position must not block the ball")
	_expect(
		int(shield_state.get_snapshot().get("active_leaf_count", -1)) == 5,
		"hidden-position probe must preserve every logical charge"
	)
	_expect(shield_state.particles.is_empty(), "hidden-position probe must not emit a break effect")


func _verify_initial_projection_collision_classification() -> void:
	for logical_index in range(5):
		var fixture := _make_rank_three_fixture()
		var shield_state: Object = fixture.get("shield_state")
		if not _expect_projection_surface(shield_state):
			return
		var display_mask := int(shield_state.call("get_display_leaf_mask"))
		var should_block := (display_mask & (1 << logical_index)) != 0
		var leaf: Dictionary = shield_state.leaves[logical_index]
		shield_state.current_angle = -float(leaf.get("base_angle", 0.0))
		var probe_position: Vector2 = shield_state.call("_get_leaf_position", leaf)
		var result: Dictionary = shield_state.resolve_ball_collision(
			_build_ball_scene(probe_position),
			_build_collision_context(),
			{}
		)
		_expect(
			bool(result.get("laurel_leaf_hit", false)) == should_block,
			"logical leaf %d collision must match its displayed representative bit" % logical_index
		)
		_expect(
			(not shield_state.particles.is_empty()) == should_block,
			"logical leaf %d particle emission must match displayed collision" % logical_index
		)
		if should_block:
			for particle in shield_state.particles:
				var particle_position: Vector2 = particle.get("position", Vector2.ZERO)
				_expect(
					particle_position.is_equal_approx(probe_position),
					"logical leaf %d particle origin must equal its displayed position" % logical_index
				)


func _verify_stable_update_rng_and_allocation_seam() -> void:
	var owner := FakeOwner.new()
	var runtime_state := FakeRuntimePerkState.new()
	runtime_state.logical_leaf_count = 5
	var shield_state := LaurelLeafShieldState.new()
	var registry := FakeRegistry.new(runtime_state, shield_state)
	var update_driver := BattleSceneRuntimePerkUpdateDriver.new()
	# Activation legitimately rolls cached leaf variants. The steady update seam
	# begins only after that one-time allocation/RNG boundary.
	update_driver.update_runtime_perk_resume(owner, registry, 0.0)
	var logical_leaves_ref: Array = shield_state.leaves

	seed(RNG_SEED)
	var control_rolls: Array[int] = [randi(), randi(), randi()]
	seed(RNG_SEED)
	var observed_rolls: Array[int] = [randi()]
	for _tick in range(120):
		update_driver.update_runtime_perk_resume(owner, registry, FRAME_DELTA)
		if shield_state.has_method("get_display_leaf_count"):
			shield_state.call("get_display_leaf_count")
	observed_rolls.append(randi())
	observed_rolls.append(randi())
	_expect(control_rolls == observed_rolls, "stable update/display projection must not advance the global RNG stream")
	_expect(is_same(logical_leaves_ref, shield_state.leaves), "stable update must reuse the logical leaf array instead of reallocating it per tick")
	_expect(shield_state.leaves.size() == 5, "stable update must keep all five rank-3 gameplay leaves")


func _verify_draw_projection_hot_path_contract() -> void:
	var source: String = FileAccess.get_file_as_string(STATE_PATH)
	var draw_body: String = _function_body(source, "func draw(")
	var collision_body: String = _function_body(source, "func resolve_ball_collision(")
	var update_body: String = _function_body(source, "func update_from_runtime(")
	var projection_body: String = _function_body(source, "func get_display_leaf_count(")
	var active_projection_body: String = _function_body(source, "func _project_display_active_leaf_count(")
	_expect(not draw_body.is_empty(), "Laurel draw hot path must be inspectable")
	_expect(not update_body.is_empty(), "Laurel production update path must be inspectable")
	_expect(not projection_body.is_empty(), "Laurel state must own one display projection getter")
	_expect(not active_projection_body.is_empty(), "Laurel state must own one remaining-charge projection")
	_expect(
		draw_body.find("get_display_leaf_mask(") >= 0
		and collision_body.find("get_display_leaf_mask(") >= 0,
		"draw and collision must consume the same displayed-subset mask"
	)
	_expect(
		draw_body.find("_get_leaf_position(leaf)") >= 0
		and collision_body.find("_get_leaf_position(leaf)") >= 0,
		"draw and collision must resolve the same logical-leaf position"
	)
	_expect(
		draw_body.find("TAU * float(display_index)") < 0,
		"draw must not redistribute displayed leaves away from their logical base angles"
	)

	for forbidden_rng in ["randi(", "randi_range(", "randf(", "randf_range(", "randomize(", "RandomNumberGenerator"]:
		_expect(draw_body.find(forbidden_rng) < 0, "draw projection must not consume RNG: %s" % forbidden_rng)
		_expect(projection_body.find(forbidden_rng) < 0, "display projection getter must not consume RNG: %s" % forbidden_rng)
	for forbidden_alloc in [".duplicate(", ".slice(", ".filter(", ".map(", "Array(", "Dictionary(", ".append("]:
		_expect(projection_body.find(forbidden_alloc) < 0, "display projection getter must stay allocation-free: %s" % forbidden_alloc)
		_expect(update_body.find(forbidden_alloc) < 0, "stable production update must not add projection allocations: %s" % forbidden_alloc)
	_expect(_count_occurrences(draw_body, " = []") <= 1, "draw projection must reuse the existing single draw-order array")
	_expect(_count_occurrences(draw_body, "draw_order.append({") <= 1, "draw projection must not add a second per-leaf Dictionary allocation site")
	_expect(draw_body.find(".duplicate(") < 0 and draw_body.find(".slice(") < 0 and draw_body.find(".filter(") < 0 and draw_body.find(".map(") < 0, "draw projection must not add collection-copy helpers to the hot path")


func _make_rank_three_fixture() -> Dictionary:
	var owner := FakeOwner.new()
	var runtime_state := FakeRuntimePerkState.new()
	runtime_state.logical_leaf_count = 5
	var shield_state := LaurelLeafShieldState.new()
	var registry := FakeRegistry.new(runtime_state, shield_state)
	var update_driver := BattleSceneRuntimePerkUpdateDriver.new()
	update_driver.update_runtime_perk_resume(owner, registry, 0.0)
	shield_state.owner_center = OWNER_CENTER
	shield_state.current_angle = 0.0
	return {
		"owner": owner,
		"runtime_state": runtime_state,
		"shield_state": shield_state,
		"registry": registry,
		"update_driver": update_driver,
	}


func _expect_projection_surface(shield_state: Object) -> bool:
	var complete := (
		shield_state != null
		and shield_state.has_method("get_display_active_leaf_count")
		and shield_state.has_method("get_display_leaf_mask")
	)
	_expect(complete, "Laurel state must expose active display count and representative mask")
	return complete


func _build_ball_scene(position: Vector2) -> Dictionary:
	return {
		"ball_pos": position,
		"ball_vel": Vector2(0.0, 8.0),
	}


func _build_collision_context() -> Dictionary:
	return {
		"player_pos": OWNER_CENTER - PLAYER_SIZE * 0.5,
		"player_paddle_size": PLAYER_SIZE,
		"ball_size": 2.0,
		"ball_render_radius": 1.0,
	}


func _first_set_bit(mask: int, limit: int) -> int:
	for index in range(limit):
		if (mask & (1 << index)) != 0:
			return index
	return -1


func _first_clear_active_bit(mask: int, logical_leaves: Array) -> int:
	for index in range(logical_leaves.size()):
		var leaf: Dictionary = logical_leaves[index]
		if bool(leaf.get("active", false)) and (mask & (1 << index)) == 0:
			return index
	return -1


func _count_set_bits(mask: int, limit: int) -> int:
	var bit_count := 0
	for index in range(limit):
		if (mask & (1 << index)) != 0:
			bit_count += 1
	return bit_count


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_function: int = source.find("\nfunc ", start + signature.length())
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _count_occurrences(source: String, marker: String) -> int:
	if marker.is_empty():
		return 0
	var count := 0
	var cursor := 0
	while true:
		cursor = source.find(marker, cursor)
		if cursor < 0:
			return count
		count += 1
		cursor += marker.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
