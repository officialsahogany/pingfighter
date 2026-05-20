extends Node

signal capture_finished(summaries: Array[Dictionary])

const BallRenderToggles := preload("res://scripts/core/ball_render_toggles.gd")
const ViperAirStrikeFlashOverride := preload("res://scripts/core/viper_air_strike_flash_override.gd")
const ViperAirborneRenderToggles := preload("res://scripts/core/viper_airborne_render_toggles.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

const MODE_WARMUP_FRAMES := 180
const MODE_CAPTURE_FRAMES := 180
const HIT_INTERVAL_FRAMES := 42
const PLAYER_FLOOR_Y := 650.0
const PLAYER_BASE_X := 302.0
const BALL_RADIUS := 22.0
const FRAME_DELTA := 1.0 / 60.0

const MODES: Array[Dictionary] = [
	{"id": "baseline", "label": "baseline", "env": "", "value": "0"},
	{
		"id": "hover_sheet",
		"label": "viper_disable_hover_sheet_draw",
		"env": ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV,
		"value": "1",
	},
	{
		"id": "hover_embers",
		"label": "viper_disable_hover_embers",
		"env": ViperAirborneRenderToggles.HOVER_EMBERS_ENV,
		"value": "1",
	},
	{
		"id": "air_strike_flash",
		"label": "viper_disable_air_strike_flash",
		"env": ViperAirStrikeFlashOverride.ENV_KEY,
		"value": "1",
	},
	{
		"id": "ball_intensity",
		"label": "disable_ball_intensity_effects",
		"env": BallRenderToggles.INTENSITY_EFFECTS_ENV,
		"value": "1",
	},
	{
		"id": "ball_energy",
		"label": "disable_ball_energy_particles",
		"env": BallRenderToggles.ENERGY_PARTICLES_ENV,
		"value": "1",
	},
]


class FakeInputReader:
	func get_snapshot() -> Dictionary:
		return {"jetpack_pressed": true}


var main_node: Node = null
var _fake_input_reader := FakeInputReader.new()
var _mode_index := -1
var _mode_frame := 0
var _global_frame := 0
var _last_frame_usec := 0
var _summaries: Array[Dictionary] = []
var _stats: Dictionary = {}
var capture_stage := 1


func configure(node: Node, stage: int = 1) -> void:
	main_node = node
	capture_stage = max(1, stage)


func _ready() -> void:
	process_priority = 100000
	_begin_mode(0)


func _process(_delta: float) -> void:
	if main_node == null or not is_instance_valid(main_node):
		capture_finished.emit(_summaries)
		queue_free()
		return
	_force_airborne_hit_frame()
	if main_node.has_method("queue_redraw"):
		main_node.queue_redraw()
	_sample_render_frame()
	_mode_frame += 1
	_global_frame += 1
	if _mode_frame >= MODE_WARMUP_FRAMES + MODE_CAPTURE_FRAMES:
		_finish_current_mode()


func _physics_process(_delta: float) -> void:
	_force_airborne_hit_frame(false)


func _begin_mode(index: int) -> void:
	if index >= MODES.size():
		_clear_all_mode_env()
		_reset_toggle_caches()
		capture_finished.emit(_summaries)
		queue_free()
		return
	_mode_index = index
	_mode_frame = 0
	_last_frame_usec = Time.get_ticks_usec()
	_stats = {
		"frames": 0,
		"calls_sum": 0.0,
		"calls_max": 0,
		"prims_sum": 0.0,
		"prims_max": 0,
		"delta_sum": 0.0,
		"delta_max": 0.0,
		"fps_sum": 0.0,
		"fps_min": 999999.0,
		"hit_frames": 0,
		"hit_delta_max": 0.0,
	}
	_configure_mode_env(MODES[index])
	_reset_mode_effect_state()
	var mode_id: String = str(MODES[index].get("id", "unknown"))
	print("[ViperAB] begin stage=%d mode=%s warmup=%d capture=%d" % [capture_stage, mode_id, MODE_WARMUP_FRAMES, MODE_CAPTURE_FRAMES])


func _finish_current_mode() -> void:
	var mode: Dictionary = MODES[_mode_index]
	var frames: int = max(1, int(_stats.get("frames", 0)))
	var fps_min: float = float(_stats.get("fps_min", 0.0))
	if fps_min >= 999999.0:
		fps_min = 0.0
	var summary := {
		"id": str(mode.get("id", "unknown")),
		"label": str(mode.get("label", "")),
		"frames": frames,
		"calls_avg": float(_stats.get("calls_sum", 0.0)) / float(frames),
		"calls_max": int(_stats.get("calls_max", 0)),
		"prims_avg": float(_stats.get("prims_sum", 0.0)) / float(frames),
		"prims_max": int(_stats.get("prims_max", 0)),
		"delta_avg_ms": float(_stats.get("delta_sum", 0.0)) / float(frames),
		"delta_max_ms": float(_stats.get("delta_max", 0.0)),
		"fps_avg": float(_stats.get("fps_sum", 0.0)) / float(frames),
		"fps_min": fps_min,
		"hit_frames": int(_stats.get("hit_frames", 0)),
		"hit_delta_max_ms": float(_stats.get("hit_delta_max", 0.0)),
	}
	_summaries.append(summary)
	print(
		"[ViperAB-Summary] mode=%s calls=%.1f/%d prims=%.1f/%d delta=%.2f/%.2fms fps=%.1f/min%.1f hit_frames=%d hit_delta_max=%.2fms"
		% [
			str(summary.get("id", "")),
			float(summary.get("calls_avg", 0.0)),
			int(summary.get("calls_max", 0)),
			float(summary.get("prims_avg", 0.0)),
			int(summary.get("prims_max", 0)),
			float(summary.get("delta_avg_ms", 0.0)),
			float(summary.get("delta_max_ms", 0.0)),
			float(summary.get("fps_avg", 0.0)),
			float(summary.get("fps_min", 0.0)),
			int(summary.get("hit_frames", 0)),
			float(summary.get("hit_delta_max_ms", 0.0)),
		]
	)
	_begin_mode(_mode_index + 1)


func _force_airborne_hit_frame(include_effects: bool = true) -> void:
	var frame_float := float(_global_frame)
	var player_x := PLAYER_BASE_X + sin(frame_float * 0.045) * 78.0
	var player_floor_pos := Vector2(player_x, PLAYER_FLOOR_Y)
	var ball_pos := Vector2(
		player_x + 74.0 + sin(frame_float * 0.11) * 34.0,
		PLAYER_FLOOR_Y - 178.0 + cos(frame_float * 0.08) * 18.0
	)
	var ball_vel := Vector2(520.0 + sin(frame_float * 0.07) * 90.0, -900.0)
	var jetpack: Object = _get_module("viper_jetpack_state")
	if jetpack != null:
		jetpack.set("active", true)
		jetpack.set("overheat", false)
		jetpack.set("hold_timer", 46.0)
		if jetpack.has_method("set_offset_y"):
			jetpack.set_offset_y(-166.0, {})
		if jetpack.has_method("update"):
			var update_result: Variant = jetpack.update(FRAME_DELTA, player_floor_pos, {
				"ball_active": true,
				"paddle_width": 155.0,
				"paddle_height": 50.0,
				"player_floor_y": PLAYER_FLOOR_Y,
				"viper_jetpack_hover_sheet_fx": false,
			}, {
				"input_reader": _fake_input_reader,
				"round_state": _get_module("round_flow_state"),
				"viper_skill_runtime": _get_module("viper_skill_runtime"),
				"runtime_perk_state": _get_module("runtime_perk_state"),
			})
			if update_result is Dictionary:
				player_floor_pos = update_result.get("player_pos", player_floor_pos)
	main_node.set("selected_character_type", "viper")
	main_node.set("selected_runtime_character_id", "viper")
	main_node.set("current_stage", capture_stage)
	main_node.set("ball_active", true)
	main_node.set("ball_visual_type", "energy")
	main_node.set("ball_pos", ball_pos)
	main_node.set("ball_vel", ball_vel)
	main_node.set("player_pos", player_floor_pos)
	main_node.set("player_paddle_width", 155.0)
	main_node.set("player_paddle_height", 50.0)
	main_node.set("player_speed", 0.0)
	main_node.set("special_gauge", 220.0)
	main_node.set("special_gauge_max", 500.0)
	_force_round_active()
	if include_effects:
		_update_ball_effects(ball_pos, ball_vel)
		_update_impact_effects()
		if _is_hit_frame():
			_trigger_synthetic_air_strike(jetpack, ball_pos, ball_vel)


func _force_round_active() -> void:
	var round_state: Object = _get_module("round_flow_state")
	if round_state != null and round_state.has_method("begin_serve") and round_state.has_method("is_waiting_for_serve"):
		if bool(round_state.is_waiting_for_serve()):
			round_state.begin_serve(Time.get_ticks_msec())


func _update_ball_effects(ball_pos: Vector2, ball_vel: Vector2) -> void:
	var ball_effects: Object = _get_module("ball_effects")
	if ball_effects == null:
		return
	if ball_effects.has_method("update_ghost_trail"):
		ball_effects.update_ghost_trail(ball_pos, BALL_RADIUS * 2.0, 1.0)
	if ball_effects.has_method("update_intensity_particles"):
		var colors: Array[Color] = [
			Color(0.08, 0.96, 1.0, 0.95),
			Color(0.56, 0.86, 1.0, 0.82),
			Color(1.0, 1.0, 1.0, 0.76),
		]
		var lod_context := {
			"selected_character_type": "viper",
			"viper_jetpack_active": true,
			"viper_jetpack_airborne": true,
			"viper_air_strike_flash_timer": 3.0,
		}
		ball_effects.update_intensity_particles(
			ball_pos,
			ball_vel,
			1.0,
			0.95,
			colors,
			ViperAirborneLod.effect_scale(lod_context)
		)


func _update_impact_effects() -> void:
	var impact_effects: Object = _get_module("impact_effects")
	if impact_effects != null and impact_effects.has_method("update"):
		impact_effects.update(FRAME_DELTA)


func _trigger_synthetic_air_strike(jetpack: Object, ball_pos: Vector2, ball_vel: Vector2) -> void:
	var impact_effects: Object = _get_module("impact_effects")
	var ball_effects: Object = _get_module("ball_effects")
	if jetpack != null and jetpack.has_method("apply_air_strike_post_hit"):
		jetpack.apply_air_strike_post_hit(ball_vel, 150.0, 190.0, {
			"ball_pos": ball_pos,
			"gauge_max": 500.0,
		}, {
			"impact_effects": impact_effects,
			"ball_effects": ball_effects,
			"runtime_perk_state": _get_module("runtime_perk_state"),
		})
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(ball_pos, ball_vel, 0.86, "viper_air_strike")


func _sample_render_frame() -> void:
	if _mode_frame < MODE_WARMUP_FRAMES:
		_last_frame_usec = Time.get_ticks_usec()
		return
	var now_usec := Time.get_ticks_usec()
	var delta_ms := float(max(0, now_usec - _last_frame_usec)) / 1000.0
	_last_frame_usec = now_usec
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var fps := float(Engine.get_frames_per_second())
	_stats["frames"] = int(_stats.get("frames", 0)) + 1
	_stats["calls_sum"] = float(_stats.get("calls_sum", 0.0)) + float(calls)
	_stats["calls_max"] = max(int(_stats.get("calls_max", 0)), calls)
	_stats["prims_sum"] = float(_stats.get("prims_sum", 0.0)) + float(prims)
	_stats["prims_max"] = max(int(_stats.get("prims_max", 0)), prims)
	_stats["delta_sum"] = float(_stats.get("delta_sum", 0.0)) + delta_ms
	_stats["delta_max"] = max(float(_stats.get("delta_max", 0.0)), delta_ms)
	_stats["fps_sum"] = float(_stats.get("fps_sum", 0.0)) + fps
	_stats["fps_min"] = min(float(_stats.get("fps_min", 999999.0)), fps)
	if _is_hit_frame():
		_stats["hit_frames"] = int(_stats.get("hit_frames", 0)) + 1
		_stats["hit_delta_max"] = max(float(_stats.get("hit_delta_max", 0.0)), delta_ms)


func _is_hit_frame() -> bool:
	return _mode_frame >= MODE_WARMUP_FRAMES and ((_mode_frame - MODE_WARMUP_FRAMES) % HIT_INTERVAL_FRAMES) == 0


func _configure_mode_env(mode: Dictionary) -> void:
	_clear_all_mode_env()
	var env_key := str(mode.get("env", ""))
	if env_key != "":
		OS.set_environment(env_key, str(mode.get("value", "1")))
	_reset_toggle_caches()


func _clear_all_mode_env() -> void:
	OS.set_environment(ViperAirborneRenderToggles.HOVER_SHEET_DRAW_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOVER_EMBERS_ENV, "0")
	OS.set_environment(ViperAirborneRenderToggles.HOLD_BAR_ENV, "0")
	OS.set_environment(ViperAirStrikeFlashOverride.ENV_KEY, "0")
	OS.set_environment(BallRenderToggles.INTENSITY_EFFECTS_ENV, "0")
	OS.set_environment(BallRenderToggles.ENERGY_PARTICLES_ENV, "0")


func _reset_toggle_caches() -> void:
	ViperAirborneRenderToggles.reset_cache_for_test()
	ViperAirStrikeFlashOverride.reset_cache_for_test()
	BallRenderToggles.reset_cache_for_test()


func _reset_mode_effect_state() -> void:
	var ball_effects: Object = _get_module("ball_effects")
	if ball_effects != null and ball_effects.has_method("clear_all"):
		ball_effects.clear_all()
	var impact_effects: Object = _get_module("impact_effects")
	if impact_effects != null and impact_effects.has_method("clear_all"):
		impact_effects.clear_all()
	var jetpack: Object = _get_module("viper_jetpack_state")
	if jetpack == null:
		return
	jetpack.set("particles", [])
	jetpack.set("air_strike_flash_timer", 0.0)
	jetpack.set("air_strike_text_timer", 0.0)
	jetpack.set("active", true)
	jetpack.set("overheat", false)
	jetpack.set("hold_timer", 46.0)


func _get_module(key: String) -> Object:
	if main_node == null or not is_instance_valid(main_node) or not main_node.has_method("_get_module"):
		return null
	var value: Variant = main_node.call("_get_module", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
