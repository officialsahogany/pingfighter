extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2StarpointRuntimeState := preload("res://scripts/stages/stage2/stage2_starpoint_runtime_state.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_retained_collection_lifecycle()
	_verify_background_delegates_starpoint_runtime_state()

	if _failures.is_empty():
		print("stage2_starpoint_runtime_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_retained_collection_lifecycle() -> void:
	var state := Stage2StarpointRuntimeState.new()
	for method_name in ["clear", "has_runtime_state", "append_drop", "append_particles", "get_drop_count", "get_drop_snapshot"]:
		_expect(state.has_method(method_name), "starpoint runtime state should own %s" % method_name)
	if not state.has_method("append_drop") or not state.has_method("append_particles") or not state.has_method("get_drop_snapshot"):
		return
	state.append_drop({"pos": Vector2(10.0, 20.0), "life": 30.0})
	state.append_particles([
		{"pos": Vector2(11.0, 21.0), "life": 2.0},
		{"pos": Vector2(12.0, 22.0), "life": 3.0},
	])
	_expect(state.get_drop_count() == 1, "starpoint runtime state should retain appended drops")
	_expect(state.particles.size() == 2, "starpoint runtime state should retain appended particles")
	_expect(state.has_runtime_state(), "starpoint runtime state should report retained visual state")

	var snapshot: Array = state.get_drop_snapshot()
	(snapshot[0] as Dictionary)["life"] = 0.0
	_expect(
		is_equal_approx(float((state.drops[0] as Dictionary).get("life", 0.0)), 30.0),
		"starpoint runtime snapshots should be deep copies"
	)
	_expect(state.clear(), "clearing populated starpoint state should report prior runtime state")
	_expect(state.drops.is_empty(), "starpoint runtime clear should remove drops")
	_expect(state.particles.is_empty(), "starpoint runtime clear should remove particles")
	_expect(not state.clear(), "clearing empty starpoint state should report no prior runtime state")


func _verify_background_delegates_starpoint_runtime_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	var coordinator_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
	_expect(
		source.find("var starpoint_state: Object = Stage2StarpointRuntimeState.new()") >= 0,
		"Stage 2 background should retain one starpoint collection owner"
	)
	_expect(coordinator_source.find("starpoint_state.append_drop") >= 0, "Stage 2 starpoint coordinator should delegate drop appends")
	_expect(coordinator_source.find("starpoint_state.append_particles") >= 0, "Stage 2 starpoint coordinator should delegate particle appends")
	_expect(source.find("starpoint_state.get_drop_count()") >= 0, "Stage 2 background should delegate starpoint counts")
	_expect(source.find("starpoint_state.get_drop_snapshot()") >= 0, "Stage 2 background should delegate starpoint snapshots")
	_expect(source.find("var starpoint_drops: Array = []") < 0, "Stage 2 background should not retain a second starpoint-drop array")
	_expect(source.find("var starpoint_particles: Array = []") < 0, "Stage 2 background should not retain a second starpoint-particle array")

	var background := Stage2PillarBackground.new()
	background.starpoint_drops = [{"pos": Vector2(30.0, 40.0)}]
	background.starpoint_particles = [{"pos": Vector2(31.0, 41.0)}]
	_expect(background.starpoint_state.drops.size() == 1, "legacy drop property should write through to the retained owner")
	_expect(background.starpoint_state.particles.size() == 1, "legacy particle property should write through to the retained owner")
	background.starpoint_state.drops.append({"pos": Vector2(50.0, 60.0)})
	_expect(background.starpoint_drops.size() == 2, "legacy drop property should read the retained owner array")
	background.reset()
	_expect(background.starpoint_drops.is_empty(), "Stage 2 reset should clear retained starpoint drops")
	_expect(background.starpoint_particles.is_empty(), "Stage 2 reset should clear retained starpoint particles")
	background.starpoint_drops = [{"pos": Vector2(70.0, 80.0)}]
	background.starpoint_particles = [{"pos": Vector2(71.0, 81.0)}]
	background._update_starpoint_drops(0.0, {"current_stage": 1}, {})
	_expect(background.starpoint_drops.is_empty(), "leaving Stage 2 should clear retained starpoint drops")
	_expect(background.starpoint_particles.is_empty(), "leaving Stage 2 should clear retained starpoint particles")

	_expect(
		GameplayStageModuleCatalog.MODULES.has("stage2_starpoint_runtime_state"),
		"stage module catalog should register the starpoint runtime state"
	)
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("stage2_starpoint_runtime_state")
	_expect(
		str(spec.get("path", "")) == "res://scripts/stages/stage2/stage2_starpoint_runtime_state.gd",
		"top-level gameplay catalog should resolve the starpoint runtime state"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
