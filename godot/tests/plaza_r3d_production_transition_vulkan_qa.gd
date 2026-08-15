extends SceneTree

# Windowed-only production R3-D seal. This owns the real loading cover, the
# production entry wrapper, PlazaScene, one building portal roundtrip, and the
# shipped 72 Hz exterior cadence in the same process.

const PlazaR3ProductionEntryHost := preload("res://scripts/plaza/plaza_r3_production_entry_host.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_ROOT := "res://.tmp/plaza_r3d_production_transition_vulkan"
const MAX_PREWARM_FRAMES := 12_000
const PIXEL_SAMPLE_STRIDE := 4
const MIN_TRANSITION_CHANGED_SAMPLES := 1_000
const EXPECTED_LEGS := 4
const MIN_ASSERTIONS := {
	"loading_timeline": 11,
	"atomic_production_reveal": 16,
	"portal_roundtrip_and_cadence": 730,
	"vulkan_evidence": 9,
}


class FakeOwner:
	extends Node2D

	var current_stage := 4
	var selected_character_type := "smasher"
	var lingpet_state := "companion"
	var active_lingpet_id := "onimaru"


class FakeSaveStore:
	extends RefCounted

	var stage_seed := 12
	var save_path := ""

	func get_or_create_stage_map_seed(_stage_id: int) -> int:
		return stage_seed

	func get_summary() -> Dictionary:
		return {"save_path": save_path, "tavern_active_quest": {}}


var _failures: Array[String] = []
var _completed_legs: Dictionary = {}
var _assertions_by_leg: Dictionary = {}
var _current_leg := ""
var _output_dir := ""
var _engine_log_path := ""
var _captures: Dictionary = {}
var _timeline: Dictionary = {}
var _cadence: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_engine_log_path = _get_user_arg_value("--plaza-r3d-engine-log-path=")
	_output_dir = OUTPUT_ROOT
	if not _prepare_output() or not await _require_windowed_vulkan():
		_finish()
		return
	var owner := FakeOwner.new()
	root.add_child(owner)
	var scene_handler := StageClearResultPlazaSceneHandler.new()
	var save_store := FakeSaveStore.new()
	save_store.save_path = _output_dir.path_join("plaza_runtime.cfg")
	var config: Dictionary = scene_handler.build_scene_config(
		4,
		save_store,
		owner,
		null,
		owner.selected_character_type,
		false
	)
	config["initial_player_position_policy"] = "first_portal"
	var host := PlazaR3ProductionEntryHost.new()
	host.name = "PlazaR3ProductionEntry"
	host.size = Vector2(VIEW_SIZE)
	owner.add_child(host)

	_begin_leg("loading_timeline")
	_expect(host.begin_entry(config), "production cold entry must begin")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var loading_status: Dictionary = host.get_debug_status()
	_expect(str(loading_status.get("phase", "")) == "loading", "first visible transition frame must remain loading")
	_expect(bool(loading_status.get("loading_visible", false)), "opaque loading owner must be visible immediately")
	_expect(not bool(loading_status.get("lifecycle_visible", true)), "R3 exterior must remain hidden during loading")
	_expect(int(loading_status.get("loading_draw_count", 0)) > 0, "loading cover must draw before prewarm completion")
	_expect(int(loading_status.get("pre_reveal_runtime_visible_count", -1)) == 0, "prewarm must expose zero runtime frames")
	_expect(await _capture("a_loading"), "loading evidence PNG must save")
	var last_progress := float(loading_status.get("progress", 0.0))
	var progress_advanced := false
	var ready := false
	for _frame_index in range(MAX_PREWARM_FRAMES):
		ready = host.advance_entry(1.0 / 72.0)
		var current: Dictionary = host.get_debug_status()
		var progress := float(current.get("progress", -1.0))
		_expect(progress + 0.000001 >= last_progress, "loading progress must be monotonic")
		progress_advanced = progress_advanced or progress > last_progress + 0.000001
		last_progress = progress
		if ready or str(current.get("phase", "")) == "rejected":
			break
		await process_frame
	_expect(ready, "real Vulkan CPU+GPU prewarm must complete within the finite frame budget")
	var ready_status: Dictionary = host.get_debug_status()
	_expect(str(ready_status.get("phase", "")) == "ready", "completed prewarm must stop at hidden ready")
	_expect(progress_advanced and is_equal_approx(last_progress, 1.0), "loading progress must visibly advance to one")
	_expect(int(ready_status.get("loading_first_draw_usec", -1)) <= int(ready_status.get("prewarm_ready_usec", -2)), "loading draw must precede readiness")
	_complete_leg("loading_timeline")

	_begin_leg("atomic_production_reveal")
	var packed: PackedScene = load("res://scenes/plaza.tscn") as PackedScene
	_expect(packed != null, "production plaza scene must load under the opaque cover")
	var plaza: Control = packed.instantiate() as Control if packed != null else null
	_expect(plaza != null, "production plaza root must instantiate")
	if plaza == null:
		_complete_leg("atomic_production_reveal")
		_finish()
		return
	plaza.name = "PlazaScene"
	plaza.visible = false
	config["r3_entry_host"] = host
	plaza.configure(config, Callable(), true)
	owner.add_child(plaza)
	var before_activation: Dictionary = (host.get_debug_status().get("lifecycle", {}) as Dictionary).duplicate(true)
	_expect(host.activate_under_loading(), "production runtime must activate beneath the drawn cover")
	var covered: Dictionary = host.get_debug_status()
	_expect(bool(covered.get("loading_visible", false)), "loading must still cover the activated runtime")
	_expect(bool(covered.get("lifecycle_visible", false)), "runtime must be active under the cover")
	_expect(not plaza.visible, "PlazaScene must remain hidden until the atomic reveal boundary")
	plaza.visible = true
	_expect(host.finish_atomic_reveal(), "production loading and exterior must switch at one boundary")
	await process_frame
	await RenderingServer.frame_post_draw
	var revealed: Dictionary = host.get_debug_status()
	var plaza_status: Dictionary = plaza.get_status()
	_expect(str(revealed.get("phase", "")) == "exterior", "production wrapper must enter exterior")
	_expect(not bool(revealed.get("loading_visible", true)), "loading must be absent after reveal")
	_expect(bool(revealed.get("lifecycle_visible", false)) and plaza.visible, "R3 exterior and production scene must be visible")
	_expect(int(revealed.get("atomic_reveal_count", 0)) == 1, "production reveal must happen exactly once")
	_expect(int(revealed.get("pre_reveal_runtime_visible_count", -1)) == 0, "no R3 runtime frame may leak before reveal")
	_expect(int(revealed.get("prewarm_ready_usec", -1)) <= int(revealed.get("activation_usec", -2)), "activation must follow readiness")
	_expect(int(revealed.get("activation_usec", -1)) <= int(revealed.get("loading_hidden_usec", -2)), "cover dismissal must follow activation")
	_expect(bool(plaza_status.get("r3_production", false)), "actual PlazaScene must report R3 production")
	_expect(int(plaza_status.get("map_seed", 0)) == 12, "production scene must retain the stage seed")
	var r1_status: Dictionary = plaza.get_map_world_host_status_for_test() as Dictionary
	_expect(not bool(r1_status.get("active", true)) and not bool(r1_status.get("attached", true)), "R1 retained exterior must not coexist with R3")
	var after_activation: Dictionary = revealed.get("lifecycle", {}) as Dictionary
	_expect(int(after_activation.get("texture_request_count", -1)) == int(before_activation.get("texture_request_count", -2)), "first reveal must issue zero texture requests")
	_expect(int(after_activation.get("runtime_build_count", -1)) == int(before_activation.get("runtime_build_count", -2)), "first reveal must build zero node pipelines")
	_expect(int(after_activation.get("first_visible_activation_usec", 99_999)) <= 2_000, "first-visible R3 work must remain under 2ms")
	_expect(await _capture("b_exterior"), "production exterior evidence PNG must save")
	_complete_leg("atomic_production_reveal")

	_begin_leg("portal_roundtrip_and_cadence")
	var interaction: Dictionary = host.try_interact()
	_expect(bool(interaction.get("valid", false)), "production first-portal policy must hit a real building portal")
	_expect(str(interaction.get("interaction_kind", "")) == "building", "production portal must resolve a building")
	_expect(plaza.trigger_interaction_for_test(true), "production PlazaScene interaction path must enter the portal")
	_expect(str(host.get_debug_status().get("phase", "")) == "interior", "production host must enter interior phase")
	_expect(bool(plaza.get_status().get("menu_open", false)), "production building interaction must open the real interior menu")
	_expect(not host.return_from_interior(Vector2(-500.0, -500.0)), "invalid portal return must fail closed")
	_expect(str(host.get_debug_status().get("phase", "")) == "interior", "invalid return must keep the exterior hidden")
	plaza.close_menu_for_test(true)
	_expect(str(host.get_debug_status().get("phase", "")) == "exterior", "portal roundtrip must finish in exterior")
	_expect(not bool(plaza.get_status().get("menu_open", true)), "production portal return must close the interior menu")
	for tick_index in range(720):
		var phase := tick_index % 240
		var direction := Vector2.RIGHT if phase < 60 else Vector2.DOWN if phase < 120 else Vector2.LEFT if phase < 180 else Vector2.UP
		var tick_status: Dictionary = plaza.move_player_for_test(direction, 1.0 / 72.0)
		var tick: Dictionary = tick_status.get("r3_last_tick", {}) as Dictionary
		_expect(bool(tick.get("valid", false)), "production 72Hz owner tick %d must remain valid" % tick_index)
	var lifecycle_status: Dictionary = host.get_debug_status().get("lifecycle", {}) as Dictionary
	var runtime_status: Dictionary = lifecycle_status.get("runtime", {}) as Dictionary
	_cadence = runtime_status.get("owner_cadence", {}) as Dictionary
	_expect(int(_cadence.get("sample_count", 0)) == 600, "production cadence must retain 600 steady samples")
	_expect(float(_cadence.get("p95_usec", 99_999.0)) < 2_000.0, "production 72Hz p95 must remain below 2ms: %s" % _cadence)
	_expect(bool(_cadence.get("within_limit", false)), "production runtime must publish a GREEN fixed-limit result")
	_expect(int(lifecycle_status.get("scene_audio_player_count", -1)) == 0, "production exterior must own zero duplicate audio players")
	_complete_leg("portal_roundtrip_and_cadence")

	_begin_leg("vulkan_evidence")
	var loading_image := _captures.get("a_loading", null) as Image
	var exterior_image := _captures.get("b_exterior", null) as Image
	_expect(loading_image != null and exterior_image != null, "both production timeline captures must exist")
	var changed_samples := _count_changed_samples(loading_image, exterior_image, PIXEL_SAMPLE_STRIDE)
	_timeline = revealed.duplicate(true)
	_timeline["loading_to_exterior_changed_samples"] = changed_samples
	_expect(changed_samples >= MIN_TRANSITION_CHANGED_SAMPLES, "loading-to-exterior pixel transition must be non-vacuous")
	_expect(loading_image.get_size() == VIEW_SIZE and exterior_image.get_size() == VIEW_SIZE, "both captures must be exact 2020x1246")
	var engine_log := FileAccess.get_file_as_string(_engine_log_path)
	_expect(engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile"), "engine log must contain real Vulkan Forward Mobile")
	_expect(str(_captures.get("a_loading_sha256", "")).length() == 64, "loading capture SHA-256 must exist")
	_expect(str(_captures.get("b_exterior_sha256", "")).length() == 64, "exterior capture SHA-256 must exist")
	_expect(int(revealed.get("loading_draw_count", 0)) > 0, "timeline must retain a non-empty loading draw count")
	_expect(int(revealed.get("loading_hidden_usec", -1)) >= int(revealed.get("prewarm_ready_usec", 0)), "timeline must prove prewarm before loading dismissal")
	_expect(_failures.is_empty(), "production Vulkan evidence must be failure-free before report")
	_complete_leg("vulkan_evidence")

	host.teardown_scene()
	plaza.queue_free()
	host.queue_free()
	owner.queue_free()
	for _frame in range(8):
		await process_frame
	_cleanup_runtime_save(save_store.save_path)
	_finish()


func _capture(slug: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path := _output_dir.path_join("%s.png" % slug)
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		return false
	_captures[slug] = image
	_captures["%s_sha256" % slug] = FileAccess.get_sha256(path)
	return true


func _prepare_output() -> bool:
	var absolute := ProjectSettings.globalize_path(_output_dir)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		_failures.append("failed to create R3-D evidence directory")
		return false
	for filename in DirAccess.get_files_at(absolute):
		if DirAccess.remove_absolute(absolute.path_join(str(filename))) != OK:
			_failures.append("failed to remove stale evidence:%s" % filename)
	return _failures.is_empty()


func _require_windowed_vulkan() -> bool:
	var driver := _get_user_arg_value("--plaza-r3d-rendering-driver=").to_lower()
	_expect(not DisplayServer.get_name().to_lower().contains("headless"), "R3-D production QA requires a window")
	_expect(RenderingServer.get_current_rendering_method().to_lower() == "mobile", "R3-D production QA requires mobile rendering")
	_expect(driver == "vulkan", "R3-D production QA requires the explicit Vulkan sentinel")
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	_expect(root.size == VIEW_SIZE, "live window must be exact 2020x1246")
	return _failures.is_empty()


func _count_changed_samples(before: Image, after: Image, stride: int) -> int:
	if before == null or after == null or before.get_size() != after.get_size():
		return 0
	var changed := 0
	for y in range(0, before.get_height(), stride):
		for x in range(0, before.get_width(), stride):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


func _begin_leg(name: String) -> void:
	_current_leg = name
	_assertions_by_leg[name] = 0


func _complete_leg(name: String) -> void:
	if _current_leg != name:
		_failures.append("GRT-040 leg completion order mismatch:%s" % name)
	if _completed_legs.has(name):
		_failures.append("GRT-040 duplicate leg completion:%s" % name)
	_completed_legs[name] = true
	_current_leg = ""


func _expect(condition: bool, message: String) -> void:
	if _current_leg != "":
		_assertions_by_leg[_current_leg] = int(_assertions_by_leg.get(_current_leg, 0)) + 1
	if not condition:
		_failures.append(message)


func _verify_completion_gate() -> void:
	if _completed_legs.size() != EXPECTED_LEGS:
		_failures.append("GRT-040 expected %d completed legs, got %d" % [EXPECTED_LEGS, _completed_legs.size()])
	for leg in MIN_ASSERTIONS.keys():
		var actual := int(_assertions_by_leg.get(leg, 0))
		var minimum := int(MIN_ASSERTIONS.get(leg, 1))
		if actual < minimum:
			_failures.append("GRT-040 leg %s executed %d assertions, expected at least %d" % [leg, actual, minimum])


func _total_assertions() -> int:
	var total := 0
	for value in _assertions_by_leg.values():
		total += int(value)
	return total


func _write_report() -> void:
	var report := {
		"schema": "plaza_r3d_production_transition_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"production_connected": true,
		"map_seed": 12,
		"timeline": _timeline,
		"cadence": _cadence,
		"capture_sha256": {
			"loading": str(_captures.get("a_loading_sha256", "")),
			"exterior": str(_captures.get("b_exterior_sha256", "")),
		},
		"completed_legs": _completed_legs.keys(),
		"assertions_by_leg": _assertions_by_leg,
		"assertion_count": _total_assertions(),
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(_output_dir.path_join("metrics.json")), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _cleanup_runtime_save(path: String) -> void:
	for candidate in [path, path.trim_suffix(".cfg") + ".last_good.cfg"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _finish() -> void:
	_verify_completion_gate()
	_write_report()
	if _failures.is_empty():
		print("plaza_r3d_production_transition_vulkan_qa: ok legs=%d assertions=%d" % [
			_completed_legs.size(),
			_total_assertions(),
		])
		print("plaza_r3d_production_transition_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(_output_dir))
		call_deferred("quit", 0)
		return
	for failure in _failures:
		push_error(failure)
	call_deferred("quit", 1)
