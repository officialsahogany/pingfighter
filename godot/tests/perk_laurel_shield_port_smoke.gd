extends SceneTree

const LaurelLeafShieldState := preload("res://scripts/characters/laurel_leaf_shield_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	var player_pos := Vector2(302.5, 675.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class FakeAudio:
	var leaf_count := 0

	func play_leaf_shield() -> void:
		leaf_count += 1


class FakeMythic:
	var leaf_bonus := 0

	func get_sacred_laurel_leaf_bonus() -> int:
		return leaf_bonus


class FakeRegistry:
	var runtime_perk_state: Object
	var mythic_item_runtime: Object

	func _init(perk_state: Object, mythic_runtime: Object = null) -> void:
		runtime_perk_state = perk_state
		mythic_item_runtime = mythic_runtime

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"mythic_item_runtime":
				return mythic_item_runtime
		return null


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("perk_laurel_shield")
	_expect(not data.is_empty(), "catalog should register Laurel Leaf")
	_expect(str(data.get("name", "")) == "오엽호신", "Five-Leaf Ward should use its Korean Mugong display name")
	_expect(int(data.get("max_level", 0)) == 5, "Laurel Leaf should have five base levels")
	_expect(str(data.get("tree", "")) == "common", "Laurel Leaf should live in the common tree")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/perks/perk_laurel_shield_perk_icon.png") != null, "Laurel Leaf perk icon should load")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/leaf.wav") != null, "Laurel Leaf sound should load")

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["perk_laurel_shield"] = 5
	_expect_close(perk_state.get_runtime_skill_bonus("perk_laurel_shield"), 5.0, "Lv.5 Laurel Leaf bonus should equal leaf count")
	perk_state.item_perk_level_bonus = 1
	_expect(perk_state.get_laurel_leaf_count() == 6, "effective Lv.6 Laurel Leaf should create six leaves")

	var mythic := FakeMythic.new()
	mythic.leaf_bonus = 3
	var registry := FakeRegistry.new(perk_state, mythic)
	_expect(perk_state.get_laurel_leaf_count(registry) == 9, "Sacred Laurel bonus should stack with perk leaves")

	var owner := FakeOwner.new()
	var state := LaurelLeafShieldState.new()
	state.update_from_runtime(owner, registry, 0.0)
	var snapshot: Dictionary = state.get_snapshot()
	_expect(bool(snapshot.get("active", false)), "Laurel shield should activate when total leaves are positive")
	_expect(int(snapshot.get("leaf_count", 0)) == 9, "Laurel shield should use effective perk + mythic leaf count")
	_expect(int(snapshot.get("active_leaf_count", 0)) == 9, "all leaves should start active")

	seed(3)
	var audio := FakeAudio.new()
	var context := {
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, owner.player_paddle_height),
		"ball_size": 28.6,
	}
	var collision_scene := {
		"ball_pos": Vector2(576.0, 700.0),
		"ball_vel": Vector2(0.0, 10.0),
	}
	var hit_result: Dictionary = state.resolve_ball_collision(collision_scene, context, {"audio": audio})
	_expect(hit_result.has("ball_vel"), "downward boss ball should collide with a back-side Laurel leaf")
	var reflected_vel: Vector2 = hit_result.get("ball_vel", Vector2.ZERO)
	_expect(reflected_vel.y < 0.0, "Laurel reflection should launch the ball upward")
	_expect(audio.leaf_count == 1, "Laurel collision should play the leaf sound")
	snapshot = state.get_snapshot()
	_expect(int(snapshot.get("active_leaf_count", 0)) == 8, "hit leaf should be consumed until regeneration")
	_expect(int(snapshot.get("particle_count", 0)) == 15, "hit leaf should spawn break particles")

	state.update_from_runtime(owner, registry, 30.0)
	snapshot = state.get_snapshot()
	_expect(int(snapshot.get("active_leaf_count", 0)) == 9, "consumed Laurel leaf should regenerate after 30 seconds")

	var upward_scene := {
		"ball_pos": Vector2(576.0, 700.0),
		"ball_vel": Vector2(0.0, -10.0),
	}
	_expect(state.resolve_ball_collision(upward_scene, context, {"audio": audio}).is_empty(), "upward player ball should not trigger Laurel shield")

	var empty_perk_state := RuntimePerkState.new()
	var empty_state := LaurelLeafShieldState.new()
	empty_state.update_from_runtime(owner, FakeRegistry.new(empty_perk_state), 0.0)
	_expect(not bool(empty_state.get_snapshot().get("active", true)), "Laurel shield should stay inactive with no leaves")

	print("perk_laurel_shield_port_smoke: ok")
	quit(0)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
