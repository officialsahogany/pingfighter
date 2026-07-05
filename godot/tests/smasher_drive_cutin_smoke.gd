extends SceneTree

const SmasherDriveCutinState := preload("res://scripts/characters/smasher_drive_cutin_state.gd")
const SmasherPowerSmashState := preload("res://scripts/characters/smasher_power_smash_state.gd")
const SmasherDriveActivationFeedbackController := preload("res://scripts/characters/smasher_drive_activation_feedback_controller.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _draw_ran := false
var _draw_probe: Node = null


class FakeDriveAudio:
	extends RefCounted

	func play_drive() -> void:
		pass


class FakeDriveCutinState:
	extends RefCounted

	var progress := 0.0
	var active := true
	var enraged := false

	func is_active() -> bool:
		return active

	func get_progress() -> float:
		return progress

	func is_enraged() -> bool:
		return enraged


# Node2D that exercises the real immediate-mode draw path (draw_* are only valid
# inside _draw, so this is the only way to catch renderer-side errors headlessly).
class DriveCutinDrawProbe:
	extends Node2D

	var host: Object = null
	var smoke: Object = null

	func _draw() -> void:
		if host == null:
			return
		var state := FakeDriveCutinState.new()
		for p in [0.0, 0.12, 0.3, 0.5, 0.7, 0.9, 1.0]:
			state.progress = float(p)
			state.active = true
			# Exercise both the normal and enraged immediate-mode writhe-ember paths.
			state.enraged = false
			host.draw_drive_cutin(self, state, Vector2(760, 750))
			state.enraged = true
			host.draw_drive_cutin(self, state, Vector2(760, 750))
		# Guard paths: null canvas + inactive state must no-op without error.
		host.draw_drive_cutin(null, state, Vector2(760, 750))
		state.active = false
		host.draw_drive_cutin(self, state, Vector2(760, 750))
		if smoke != null:
			smoke._draw_ran = true


func _init() -> void:
	_test_state_lifecycle()
	_test_state_phases()
	_test_feedback_triggers_drive_cutin()
	_test_enraged_flag()
	_test_power_state_update_and_reset()
	_test_drive_character_texture()
	_test_runtime_node_prewarm()
	_test_curve_helpers()
	_test_triangle_panel_geometry()
	_test_localized_titles()
	_start_draw_probe()


func _test_state_lifecycle() -> void:
	var state := SmasherDriveCutinState.new()
	_expect(not state.is_active(), "drive cut-in starts inactive")
	state.begin(0.5)
	_expect(state.is_active(), "begin() activates the drive cut-in")
	_expect(state.get_progress() == 0.0, "progress starts at 0")
	state.update(0.25)
	_expect(absf(state.get_progress() - 0.5) < 0.01, "progress tracks elapsed/duration")
	state.update(0.30)
	_expect(not state.is_active(), "drive cut-in auto-deactivates past duration")
	state.begin(0.5)
	state.reset()
	_expect(not state.is_active(), "reset() clears active")


func _test_state_phases() -> void:
	var state := SmasherDriveCutinState.new()
	state.begin(1.0)
	_expect(state.get_phase() == "in", "phase at 0 is in")
	state.update(0.30)
	_expect(state.get_phase() == "hold", "phase at 0.30 is hold, got %s" % state.get_phase())
	state.update(0.40)
	_expect(state.get_phase() == "out", "phase at 0.70 is out, got %s" % state.get_phase())


func _test_feedback_triggers_drive_cutin() -> void:
	var controller := SmasherDriveActivationFeedbackController.new()
	var power_state := SmasherPowerSmashState.new()
	_expect(not power_state.is_drive_cutin_active(), "drive cut-in inactive before activation")
	controller.apply_feedback({}, {"audio": FakeDriveAudio.new(), "power_state": power_state}, {}, null, null)
	_expect(power_state.is_drive_cutin_active(), "drive activation feedback should begin the drive cut-in")


func _test_enraged_flag() -> void:
	# State-level: begin(duration, enraged) stores it; default + reset clear it.
	# Duration stays first-positional (other tests call begin(<duration>)).
	var state := SmasherDriveCutinState.new()
	_expect(not state.is_enraged(), "drive cut-in starts non-enraged")
	state.begin(0.5)
	_expect(not state.is_enraged(), "begin() without enraged flag stays non-enraged")
	state.begin(0.5, true)
	_expect(state.is_enraged(), "begin(duration, true) marks the cut-in enraged")
	state.reset()
	_expect(not state.is_enraged(), "reset() clears enraged")

	# Activation: combo-charged drive (consume_combo) => enraged cut-in.
	var controller := SmasherDriveActivationFeedbackController.new()
	var combo_power := SmasherPowerSmashState.new()
	controller.apply_feedback(
		{}, {"audio": FakeDriveAudio.new(), "power_state": combo_power}, {"consume_combo": true}, null, null
	)
	_expect(combo_power.is_drive_cutin_active(), "combo drive still begins the cut-in")
	_expect(combo_power.is_drive_cutin_enraged(), "combo-charged drive plays the enraged cut-in")

	# Non-combo drive => normal cut-in, never enraged.
	var plain_power := SmasherPowerSmashState.new()
	controller.apply_feedback(
		{}, {"audio": FakeDriveAudio.new(), "power_state": plain_power}, {}, null, null
	)
	_expect(plain_power.is_drive_cutin_active(), "non-combo drive begins the cut-in")
	_expect(not plain_power.is_drive_cutin_enraged(), "non-combo drive stays non-enraged")


func _test_power_state_update_and_reset() -> void:
	var power_state := SmasherPowerSmashState.new()
	power_state.begin_drive_cutin()
	_expect(power_state.is_drive_cutin_active(), "begin_drive_cutin activates")
	# update_effects advances the cut-in every gameplay frame (fps_scale ~ 1 per 60fps frame).
	# 90 frames = 1.5s > the 1.35s cut-in duration.
	for i in 90:
		power_state.update_effects(1.0, Vector2.ZERO, true, 18.0)
	_expect(not power_state.is_drive_cutin_active(), "update_effects advances the drive cut-in to completion")
	power_state.begin_drive_cutin()
	power_state.reset()
	_expect(not power_state.is_drive_cutin_active(), "power_state.reset() clears the drive cut-in")


func _test_drive_character_texture() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var texture := host._get_drive_texture(SkillCutinOverlayHost.DRIVE_CHARACTER_PATH)
	_expect(texture != null, "dedicated drive cut-in character pose should load")
	if texture != null:
		_expect(texture.get_width() > 1 and texture.get_height() > 1, "drive character texture should have size")


func _test_runtime_node_prewarm() -> void:
	var host := SkillCutinOverlayHost.new()
	var parent := Node2D.new()
	get_root().add_child(parent)
	host.prewarm_runtime_nodes(parent)
	var fx_host := parent.get_node_or_null(SkillCutinOverlayHost.DRIVE_CUTIN_FX_HOST_NAME)
	_expect(fx_host != null, "drive cut-in runtime node prewarm should create the FX host")
	if fx_host != null and fx_host.has_method("get_debug_status"):
		var status: Dictionary = fx_host.get_debug_status()
		_expect(not bool(status.get("active", true)), "prewarmed drive FX host should stay hidden")
		_expect(bool(status.get("particle_texture_ready", false)), "prewarmed drive FX host should have its texture ready")
	host.prewarm_runtime_nodes(parent)
	_expect(
		parent.get_children().filter(func(child: Node) -> bool: return child.name == SkillCutinOverlayHost.DRIVE_CUTIN_FX_HOST_NAME).size() == 1,
		"drive cut-in runtime node prewarm should be idempotent"
	)
	parent.queue_free()


func _test_curve_helpers() -> void:
	var host := SkillCutinOverlayHost.new()
	_expect(absf(host._drive_slide_ratio(0.0) - 1.0) < 0.01, "slide starts fully off-screen at progress 0")
	_expect(host._drive_slide_ratio(0.4) == 0.0, "slide is seated during hold")
	_expect(host._drive_slide_ratio(1.0) > 0.9, "slide exits left near progress 1")
	_expect(host._drive_alpha(0.0) <= 0.01, "alpha fades in from 0")
	_expect(host._drive_alpha(0.5) == 1.0, "alpha is full during hold")
	_expect(host._drive_alpha(1.0) <= 0.01, "alpha fades out to 0")
	_expect(host._drive_impact_punch(0.0) == 1.0, "impact punch starts at neutral scale")
	_expect(host._drive_impact_punch(0.12) > 1.05, "impact punch should pop at the seated hit beat")
	_expect(absf(host._drive_impact_punch(0.5) - 1.0) < 0.01, "impact punch should settle during hold")


func _test_triangle_panel_geometry() -> void:
	var host := SkillCutinOverlayHost.new()
	var view := Vector2(760, 750)
	var points: PackedVector2Array = host._drive_triangle_points(view, 0.0)
	_expect(points.size() == 3, "drive cut-in panel should be a triangle")
	if points.size() != 3:
		return
	_expect(absf(points[0].x) < 0.01, "triangle panel top-left should be attached to the left wall")
	_expect(points[1].x > view.x * 0.30, "triangle panel should reach into the upper-left play view")
	_expect(absf(points[2].x) < 0.01, "triangle panel lower-left should stay attached to the left wall")
	_expect(points[2].y > view.y * 0.45, "triangle panel should taper down the left wall")
	_expect(
		not host._should_draw_drive_edge_flames(points[2], points[0]),
		"left-wall triangle edge should keep the seam but skip outward flame offsets"
	)
	_expect(
		host._should_draw_drive_edge_flames(points[0], points[1]),
		"top triangle edge should still draw drive flame offsets"
	)
	_expect(
		host._should_draw_drive_edge_flames(points[1], points[2]),
		"diagonal triangle edge should still draw drive flame offsets"
	)
	var expanded: PackedVector2Array = host._expanded_drive_polygon(points, view.y * 0.02)
	_expect(expanded.size() == 3, "expanded drive triangle should keep the same vertex count")


func _test_localized_titles() -> void:
	var original_language: String = LanguageSettings.get_language()
	var host := SkillCutinOverlayHost.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_expect(
		host._get_localized_skill_title(SkillCutinOverlayHost.SKILL_DRIVE, "") == "드라이브",
		"drive cut-in title should use the Korean skill name by default"
	)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(
		host._get_localized_skill_title(SkillCutinOverlayHost.SKILL_DRIVE, "") == "Drive",
		"drive cut-in title should localize to English"
	)
	var power_profile: Dictionary = host._get_cutin_profile(SkillCutinOverlayHost.SKILL_POWER_SMASHING)
	_expect(
		host._get_profile_title(power_profile) == "Power Smashing",
		"power-smashing cut-in profile title should localize to English"
	)
	var ghost_profile: Dictionary = host._get_cutin_profile(SkillCutinOverlayHost.SKILL_GHOST_SHOT)
	_expect(
		host._get_profile_title(ghost_profile) == "Ghost Smashing",
		"ghost-smashing cut-in profile title should localize to English"
	)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	var ghost_zh: Dictionary = LanguageSettings.SKILL_DATA_ZH.get(SkillCutinOverlayHost.SKILL_GHOST_SHOT, {})
	_expect(
		host._get_profile_title(ghost_profile) == str(ghost_zh.get("korean", "")),
		"ghost-smashing cut-in profile title should localize through skill data tables"
	)
	_expect(
		host._get_localized_skill_title("", "Fallback") == "Fallback",
		"cut-in title localization should keep explicit fallback text for unknown skill ids"
	)
	LanguageSettings.set_language(original_language)


func _start_draw_probe() -> void:
	var host := SkillCutinOverlayHost.new()
	host.prewarm_assets()
	var probe := DriveCutinDrawProbe.new()
	probe.host = host
	probe.smoke = self
	get_root().add_child(probe)
	_draw_probe = probe
	probe.queue_redraw()
	# Let a few idle frames run so the probe's _draw executes, then finish.
	create_timer(0.1).timeout.connect(_finish_after_draw)


func _finish_after_draw() -> void:
	_expect(_draw_ran, "drive cut-in draw probe should run _draw without fatal errors")
	if _draw_probe != null and is_instance_valid(_draw_probe):
		_draw_probe.queue_free()
	_draw_probe = null
	ProjectResourceLoader.clear_caches()
	await _drain_frames(24)
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("smasher_drive_cutin_smoke: ok")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		quit(1)


func _drain_frames(frame_count: int) -> void:
	for i in frame_count:
		await process_frame


func _expect(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append(message if message != "" else "assertion failed")
