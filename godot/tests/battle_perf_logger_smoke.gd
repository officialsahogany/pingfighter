extends SceneTree

const BattlePerfLogger := preload("res://scripts/core/battle_perf_logger.gd")
const GameplayCoreModuleCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const BattleLoadingStainedGlassHost := preload("res://scripts/core/battle_loading_stained_glass_host.gd")

var _failures: Array[String] = []


class ProcessProbe:
	extends Node

	func _process(_delta: float) -> void:
		pass


class PhysicsProbe:
	extends Node

	func _physics_process(_delta: float) -> void:
		pass


class HeaderOwner:
	extends Node

	var current_stage := 1
	var selected_character_type := "smasher"
	var weather_type := ""


func _init() -> void:
	_verify_catalog_registration()
	_verify_sample_collection()
	_verify_boundary_summary()
	_verify_gap_summary()
	_verify_status_contract()
	_verify_live_owner_header_context()
	_verify_process_node_summary()
	_verify_jetpack_state_label()
	_verify_physics_monitor_summary()
	_verify_spike_detail_summary()
	_verify_spike_window_summary()

	if _failures.is_empty():
		print("battle_perf_logger_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_registration() -> void:
	var catalog := GameplayCoreModuleCatalog.new()
	var spec: Dictionary = catalog.get_spec("battle_perf_logger")
	_expect(str(spec.get("path", "")) == "res://scripts/core/battle_perf_logger.gd", "battle perf logger should be registered in the core catalog")
	_expect(str(spec.get("label", "")) == "battle performance logger", "battle perf logger should expose a readable catalog label")


func _verify_sample_collection() -> void:
	var logger := BattlePerfLogger.new()
	logger.log_checked = true
	logger.log_enabled = true
	var start: int = logger.begin_sample()
	_expect(start > 0, "enabled logger should return a non-zero sample start")
	logger.finish_sample("sample.draw", start)
	_expect(logger.samples.has("sample.draw"), "finish_sample should store a sample by label")
	var sample: Dictionary = logger.samples.get("sample.draw", {})
	_expect(int(sample.get("count", 0)) == 1, "sample count should increment once")
	_expect(int(sample.get("max_usec", 0)) >= 0, "sample max should be stored in microseconds")
	logger.record_value_sample("sample.value", 1234)
	_expect(logger.samples.has("sample.value"), "record_value_sample should store externally measured values")
	logger.detail_checked = true
	logger.detail_enabled = false
	_expect(not logger.should_sample_detail("sample.draw"), "detail samples should be disabled by default")
	logger.detail_checked = true
	logger.detail_enabled = true
	_expect(logger.should_sample_detail("sample.draw"), "detail sample flag should enable nested timings")
	logger.finish_sample("sample.spike", Time.get_ticks_usec() - 9000)
	logger.record_value_sample("process.shell.delta", 20000)
	var spike_summary: String = logger._build_spike_summary()
	_expect(spike_summary.find("sample.spike") >= 0, "spike summary should include samples over threshold")
	_expect(spike_summary.find("sample.draw") < 0, "spike summary should omit small samples")
	_expect(spike_summary.find("process.shell.delta") < 0, "spike summary should omit frame delta samples")


func _verify_boundary_summary() -> void:
	var logger := BattlePerfLogger.new()
	logger.log_checked = true
	logger.log_enabled = true
	var now_usec: int = Time.get_ticks_usec()
	logger.finish_sample("physics.shell.total", now_usec - 1200)
	logger.finish_sample("physics.frame.total", now_usec - 800)
	logger.finish_sample("process.shell.total", now_usec - 900)
	logger.finish_sample("process.frame.total", now_usec - 600)
	logger.finish_sample("draw.shell.total", now_usec - 700)
	logger.record_value_sample("draw.frame.total", 650)
	logger.record_value_sample("00.playfield_frame_total", 500)
	logger.record_value_sample("process.shell.delta", 16666)
	logger.record_value_sample("physics.shell.delta", 8333)
	var summary: String = logger._build_boundary_summary()
	_expect(summary.find("delta=proc=16.67ms") >= 0, "boundary summary should include process delta timing")
	_expect(summary.find("phys=8.33ms(max=8.33)") >= 0, "boundary summary should include physics delta timing")
	_expect(summary.find("shell=phys=") >= 0, "boundary summary should include shell timings")
	_expect(summary.find("frame=phys=") >= 0, "boundary summary should include frame-controller timings")
	_expect(summary.find("playfield=0.50ms") >= 0, "boundary summary should preserve playfield draw timing beside frame draw")
	_expect(summary.find("gap=mon-shell") >= 0, "boundary summary should include monitor-to-shell gaps")
	_expect(summary.find("proc_after_draw=") >= 0, "boundary summary should split process gap after accounted draw")
	_expect(summary.find("idle=frame=") >= 0, "boundary summary should expose process-delta residual outside measured frame work")
	_expect(summary.find("shell-frame") >= 0, "boundary summary should include shell-to-frame gaps")
	_expect(summary.find("driver=") >= 0, "boundary summary should include the active rendering driver")
	_expect(summary.find("api=") >= 0, "boundary summary should include the rendering adapter API")
	_expect(summary.find("cap=") >= 0, "boundary summary should include the effective render FPS cap label")
	_expect(summary.find("ptick=") >= 0, "boundary summary should include the active physics tick rate")
	_expect(summary.find("lod=") >= 0, "boundary summary should include the active render-quality LOD scale")


func _verify_gap_summary() -> void:
	var logger := BattlePerfLogger.new()
	logger.log_checked = true
	logger.log_enabled = true
	logger.record_value_sample("process.shell.delta", 20000)
	logger.record_value_sample("process.shell.total", 500)
	logger.record_value_sample("draw.shell.total", 1500)
	logger.record_value_sample("draw.scene.playfield", 2500)
	logger.record_value_sample("actors.stage2.player", 1300)
	logger.record_value_sample("07.ball_effects", 1700)
	logger.record_value_sample("active_item.field_items", 900)
	logger.record_value_sample("physics.shell.total", 700)
	logger.record_value_sample("physics.stage5.hongryun.fireball_spawn", 120)
	logger.record_value_sample("stage2.pillar.hud", 420)
	logger.record_value_sample("stage3.playfield.kuromi", 430)
	logger.record_value_sample("stage3.pillar.hud_scene", 440)
	logger.record_value_sample("stage5.playfield.inferno", 450)
	logger.record_value_sample("stage5.pillar.hud_scene", 460)
	logger.record_value_sample("draw.frame.pillar_overlay", 300)
	logger.record_counter_sample("active_item.field_items.before", 12.0)
	logger.record_counter_sample("active_item.field_items.before", 18.0)
	var summary: String = logger._build_gap_summary()
	_expect(summary.find("perf=proc-shell=") >= 0, "gap summary should directly compare Performance.TIME_PROCESS against shell process time")
	_expect(summary.find("proc-shell-draw=") >= 0, "gap summary should split the post-draw process remainder")
	_expect(summary.find("idle=frame=") >= 0, "gap summary should expose the process-delta residual after monitor-accounted work")
	_expect(summary.find("phys-shell=") >= 0, "gap summary should directly compare Performance.TIME_PHYSICS_PROCESS against shell physics time")
	_expect(summary.find("gap_v=2") >= 0, "gap summary should expose its format version near the gap header")
	_expect(summary.find("class=") >= 0, "gap summary should classify the dominant gap shape")
	_expect(summary.find("render=calls=") >= 0, "gap summary should include render server draw-call load")
	_expect(summary.find("samples=proc=") >= 0, "gap summary should disclose process/physics/draw sample counts")
	_expect(summary.find("driver=") >= 0, "gap summary should include the active rendering driver in display metadata")
	_expect(summary.find("api=") >= 0, "gap summary should include the rendering adapter API in display metadata")
	_expect(summary.find("cap=") >= 0, "gap summary should include the effective render FPS cap label in display metadata")
	_expect(summary.find("ptick=") >= 0, "gap summary should include the active physics tick rate in display metadata")
	_expect(summary.find("hot=draw.scene.playfield=") >= 0, "gap summary should surface hot non-aggregate samples below spike threshold")
	_expect(summary.find("actors.stage2.player=") >= 0, "gap summary should surface focused actor sub-stage draw labels")
	_expect(summary.find("07.ball_effects=") >= 0, "gap summary should surface focused playfield draw labels beside the generic hot list")
	_expect(summary.find("active_item.field_items=") >= 0, "playfield hot summary should include nested playfield item draw labels")
	_expect(summary.find("physics.stage5.hongryun.fireball_spawn=") >= 0, "gap summary should surface focused Stage 5 labels even below generic hot thresholds")
	_expect(summary.find("stage2.pillar.hud=") >= 0, "gap summary should surface Stage 2 pillar labels even below generic hot thresholds")
	_expect(summary.find("stage3.playfield.kuromi=") >= 0, "gap summary should surface Stage 3 playfield labels even below generic hot thresholds")
	_expect(summary.find("stage3.pillar.hud_scene=") >= 0, "gap summary should surface Stage 3 pillar labels even below generic hot thresholds")
	_expect(summary.find("stage5.playfield.inferno=") >= 0, "gap summary should surface Stage 5 playfield labels even below generic hot thresholds")
	_expect(summary.find("stage5.pillar.hud_scene=") >= 0, "gap summary should surface Stage 5 pillar labels even below generic hot thresholds")
	_expect(summary.find("draw.frame.pillar_overlay=") >= 0, "gap summary should surface pillar overlay frame labels in stage hot output")
	_expect(summary.find("counters=active_item.field_items.before=15.0/18.0(n2)") >= 0, "gap summary should include averaged counter samples for item-count diagnosis")
	var cadence_class: String = logger._classify_gap({
		"proc_gap_ms": 10.0,
		"phys_gap_ms": 10.0,
		"proc_after_draw_ms": 3.0,
		"phys_shell_ms": 2.0,
		"draw_shell_ms": 6.0,
		"draw_calls": 240,
		"primitives": 7200,
		"proc_shell_count": 53,
		"phys_shell_count": 45,
		"draw_shell_count": 98,
	}, 10.0)
	_expect(cadence_class.find("physics-cadence") >= 0, "gap classifier should recognize 144Hz draw vs 60Hz physics sample cadence")
	_expect(cadence_class.find("engine-physics") < 0, "cadence-shaped physics gaps should not be reported as engine physics overhead")
	var monitor_lag_class: String = logger._classify_gap({
		"process_ms": 975.0,
		"proc_gap_ms": 974.0,
		"phys_gap_ms": 0.1,
		"proc_after_draw_ms": 973.0,
		"phys_shell_ms": 0.1,
		"proc_shell_ms": 0.1,
		"draw_shell_ms": 0.2,
		"proc_shell_max_ms": 0.2,
		"draw_shell_max_ms": 2.0,
		"draw_calls": 9,
		"primitives": 36,
		"proc_shell_count": 101,
		"phys_shell_count": 50,
		"draw_shell_count": 101,
	}, 142.0)
	_expect(monitor_lag_class.find("monitor-process-lag") >= 0, "gap classifier should flag stale process monitor values that exceed local frame samples")
	_expect(monitor_lag_class.find("engine-process") < 0, "stale process monitor values should not be reported as real engine-process overhead")
	var negative_idle_lag_class: String = logger._classify_gap({
		"process_ms": 77.0,
		"proc_gap_ms": 76.0,
		"phys_gap_ms": 0.1,
		"proc_after_draw_ms": 71.0,
		"frame_idle_ms": -65.0,
		"phys_shell_ms": 0.1,
		"proc_shell_ms": 0.6,
		"draw_shell_ms": 5.3,
		"proc_shell_max_ms": 25.9,
		"draw_shell_max_ms": 26.8,
		"draw_calls": 715,
		"primitives": 24384,
		"proc_shell_count": 61,
		"phys_shell_count": 45,
		"draw_shell_count": 61,
	}, 77.5)
	_expect(negative_idle_lag_class.find("monitor-process-lag") >= 0, "large negative frame idle should classify as stale process monitor lag")
	_expect(negative_idle_lag_class.find("engine-process") < 0, "large negative frame idle should not be reported as real engine-process work")
	var physics_monitor_lag_class: String = logger._classify_gap({
		"process_ms": 16.9,
		"physics_ms": 22.8,
		"proc_gap_ms": 16.6,
		"phys_gap_ms": 19.8,
		"proc_after_draw_ms": 6.5,
		"frame_idle_ms": 41.2,
		"phys_shell_ms": 3.1,
		"phys_shell_max_ms": 5.1,
		"proc_shell_ms": 0.3,
		"draw_shell_ms": 10.1,
		"draw_calls": 447,
		"primitives": 17972,
		"proc_shell_count": 14,
		"phys_shell_count": 47,
		"draw_shell_count": 56,
		"physics_2d_active": 0,
		"physics_2d_pairs": 0,
		"physics_2d_islands": 0,
	}, 131.1)
	_expect(physics_monitor_lag_class.find("monitor-physics-lag") >= 0, "empty 2D physics monitor gaps should be reported as stale physics monitor lag")
	_expect(physics_monitor_lag_class.find("engine-physics") < 0, "empty 2D physics monitor gaps should not be reported as real engine physics overhead")


func _verify_status_contract() -> void:
	var logger := BattlePerfLogger.new()
	logger.log_checked = true
	logger.log_enabled = true
	logger.sample_summary_checked = true
	logger.sample_summary_enabled = false
	var status: Dictionary = logger.get_status()
	_expect(str(status.get("env", "")) == BattlePerfLogger.PERF_LOG_ENV, "status should expose the enabling environment variable")
	_expect(str(status.get("detail_env", "")) == BattlePerfLogger.PERF_DETAIL_ENV, "status should expose the detail environment variable")
	_expect(str(status.get("samples_env", "")) == BattlePerfLogger.PERF_SAMPLES_ENV, "status should expose the full sample-summary environment variable")
	_expect(str(status.get("interval_env", "")) == BattlePerfLogger.PERF_LOG_INTERVAL_ENV, "status should expose the log interval environment variable")
	_expect(str(status.get("gap_threshold_env", "")) == BattlePerfLogger.PERF_GAP_THRESHOLD_ENV, "status should expose the gap threshold environment variable")
	_expect(str(status.get("spike_threshold_env", "")) == BattlePerfLogger.PERF_SPIKE_THRESHOLD_ENV, "status should expose the spike threshold environment variable")
	_expect(str(status.get("flag_path", "")) == BattlePerfLogger.PERF_LOG_FLAG_PATH, "status should expose the enabling flag path")
	_expect(str(status.get("detail_flag_path", "")) == BattlePerfLogger.PERF_DETAIL_FLAG_PATH, "status should expose the detail flag path")
	_expect(str(status.get("samples_flag_path", "")) == BattlePerfLogger.PERF_SAMPLES_FLAG_PATH, "status should expose the full sample-summary flag path")
	_expect(bool(status.get("enabled", false)), "status should report enabled when logger is forced on")
	_expect(not bool(status.get("samples_enabled", true)), "full sample-summary logging should stay disabled by default")
	_expect(is_equal_approx(float(status.get("log_interval_sec", 0.0)), BattlePerfLogger.DEFAULT_LOG_INTERVAL_SEC), "status should expose default log interval")
	_expect(int(status.get("spike_threshold_usec", 0)) == BattlePerfLogger.DEFAULT_SPIKE_THRESHOLD_USEC, "status should expose default spike threshold")
	_expect(is_equal_approx(float(status.get("gap_threshold_msec", 0.0)), BattlePerfLogger.DEFAULT_GAP_THRESHOLD_MSEC), "status should expose default gap threshold")
	logger.sample_summary_checked = true
	logger.sample_summary_enabled = true
	var sample_status: Dictionary = logger.get_status()
	_expect(bool(sample_status.get("samples_enabled", false)), "status should report full sample-summary logging when forced on")


func _verify_live_owner_header_context() -> void:
	var logger := BattlePerfLogger.new()
	var owner := HeaderOwner.new()
	owner.current_stage = 2
	owner.selected_character_type = "viper"
	owner.weather_type = "storm"
	logger.set_scene_owner(owner)
	logger.remember_context({
		"current_stage": 1,
		"selected_character_type": "smasher",
		"active_weather_type": "rain",
	})
	var header_context: Dictionary = logger._build_header_context({})
	_expect(int(header_context.get("current_stage", 0)) == 2, "battle perf header should prefer the live owner stage over stale remembered context")
	_expect(str(header_context.get("selected_character_type", "")) == "viper", "battle perf header should prefer the live owner character")
	_expect(str(header_context.get("active_weather_type", "")) == "storm", "battle perf header should mirror owner weather_type when active_weather_type is absent")
	var header: String = logger._build_log_header({"current_stage": 1})
	_expect(header.find("stage=2") >= 0, "battle perf header string should not stay on a stale stage")
	owner.current_stage = 3
	var advanced_header: String = logger._build_log_header({})
	_expect(advanced_header.find("stage=3") >= 0, "battle perf header should follow later stage transitions even with an empty maybe_log context")
	owner.free()


func _verify_process_node_summary() -> void:
	var logger := BattlePerfLogger.new()
	var owner := Node.new()
	owner.name = "BattleShell"
	owner.set_process(true)
	owner.set_physics_process(true)
	var child := Node.new()
	child.name = "DetachedFxHost"
	child.set_process(true)
	owner.add_child(child)
	var process_probe := ProcessProbe.new()
	process_probe.name = "ScriptProcessProbe"
	process_probe.set_process(false)
	owner.add_child(process_probe)
	var physics_probe := PhysicsProbe.new()
	physics_probe.name = "ScriptPhysicsProbe"
	physics_probe.set_physics_process(false)
	owner.add_child(physics_probe)
	var stale_loading_host := BattleLoadingStainedGlassHost.new()
	stale_loading_host.name = "BattleLoadingStainedGlassHost"
	stale_loading_host.visible = false
	stale_loading_host.set_process(false)
	owner.add_child(stale_loading_host)
	logger.set_scene_owner(owner)
	var summary: String = logger._build_process_node_summary()
	_expect(summary.find("scan=owner") >= 0, "gap summary should disclose whether it scanned the owner subtree or scene root")
	_expect(summary.find("nodes=5") >= 0, "gap summary should expose how many nodes were scanned")
	_expect(summary.find("script_nodes=") >= 0, "gap summary should expose script-node coverage")
	_expect(summary.find("ignored_stale=1") >= 0, "gap summary should identify stale inactive loading hosts separately")
	_expect(summary.find("scan_v=2") >= 0, "gap summary should expose the process scanner version")
	_expect(summary.find("process_nodes=") >= 0, "gap summary should expose active process node counts")
	_expect(summary.find("physics_nodes=") >= 0, "gap summary should expose active physics node counts")
	_expect(summary.find("callbacks=") >= 0, "gap summary should expose script callback coverage, not only active process nodes")
	_expect(summary.find("inactive=") >= 0, "gap summary should disclose script callbacks that are currently inactive")
	_expect(summary.find("callback_outside=0") >= 0, "inactive callback definitions should not be counted as active callback leaks")
	_expect(summary.find("DetachedFxHost") >= 0, "gap summary should list process nodes outside the battle shell")
	_expect(summary.find("ScriptProcessProbe") >= 0, "gap summary should list process callback nodes outside the battle shell")
	_expect(summary.find("ScriptPhysicsProbe") >= 0, "gap summary should list physics callback nodes outside the battle shell")
	owner.free()


func _verify_spike_detail_summary() -> void:
	var logger := BattlePerfLogger.new()
	_expect(not logger._should_emit_spike_detail(), "spike detail should not fire on an empty window")
	logger.log_checked = true
	logger.log_enabled = true
	# delta trigger: process.shell.delta max above 40 ms
	logger.record_value_sample("process.shell.delta", 50000)
	_expect(logger._should_emit_spike_detail(), "spike detail should trigger when process.shell.delta exceeds 40 ms")
	logger.samples.clear()
	# phys.shell trigger: physics.shell.total max above 8 ms
	logger.record_value_sample("physics.shell.total", 12000)
	_expect(logger._should_emit_spike_detail(), "spike detail should trigger when physics.shell.total exceeds 8 ms")
	logger.samples.clear()
	# draw.shell trigger: draw.shell.total max above 16 ms
	logger.record_value_sample("draw.shell.total", 20000)
	_expect(logger._should_emit_spike_detail(), "spike detail should trigger when draw.shell.total exceeds 16 ms")
	# detail output: include every label sorted by max desc
	logger.samples.clear()
	logger.record_value_sample("physics.shell.total", 28000)
	logger.record_value_sample("physics.callback.effects", 24000)
	logger.record_value_sample("physics.update_driver.flow_update", 12000)
	logger.record_value_sample("physics.viper.jetpack_update", 500)
	var detail: String = logger._build_spike_detail_summary()
	_expect(detail.find("physics.shell.total=") >= 0, "spike detail should expose physics.shell.total when above threshold")
	_expect(detail.find("physics.callback.effects=") >= 0, "spike detail should expose sub-section labels (physics.callback.effects)")
	_expect(detail.find("physics.viper.jetpack_update=") >= 0, "spike detail should include small labels that hot/spike filters would hide")
	var shell_idx: int = detail.find("physics.shell.total=")
	var effects_idx: int = detail.find("physics.callback.effects=")
	_expect(shell_idx >= 0 and effects_idx >= 0 and shell_idx < effects_idx, "spike detail should sort by max desc (28ms before 24ms)")
	logger.samples.clear()


func _verify_spike_window_summary() -> void:
	var logger := BattlePerfLogger.new()
	logger.log_checked = true
	logger.log_enabled = true
	_expect(logger._build_spike_window_summary() == "", "spike window summary should stay empty without a trigger")
	logger.record_value_sample("draw.shell.frame_controller", 12000)
	logger.record_value_sample("draw.frame.battle_scene", 9000)
	logger.record_value_sample("00.playfield_frame_total", 5100)
	logger.record_value_sample("01.actors.total", 5200)
	logger.record_value_sample("actors.stage2.player", 2100)
	logger.record_value_sample("30.mythic_item_field", 1900)
	logger.record_value_sample("context.actor", 3500)
	logger.record_value_sample("29.active_item_field", 1400)
	logger.record_value_sample("active_item.field_effects", 1300)
	logger.record_counter_sample("active_item.field_items.after", 1.0)
	var summary: String = logger._build_spike_window_summary()
	_expect(summary.find("trigger=draw.shell.frame_controller=") >= 0, "spike window should expose the triggering draw shell sample")
	_expect(summary.find("draw.frame.battle_scene=") >= 0, "spike window should include battle-scene draw timing")
	_expect(summary.find("01.actors.total=") >= 0, "spike window should include actor draw timing")
	_expect(summary.find("actors.stage2.player=") >= 0, "spike window should include actor sub-stage draw timing")
	_expect(summary.find("29.active_item_field=") >= 0, "spike window should include active item field timing")
	_expect(summary.find("30.mythic_item_field=") >= 0, "spike window should include mythic item field timing")
	_expect(summary.find("active_item.field_effects=") >= 0, "spike window should include nested active item field timing")
	_expect(summary.find("counters=active_item.field_items.after=1.0/1.0(n1)") >= 0, "spike window should preserve item-count counters")
	var shell_idx: int = summary.find("max_hot=draw.shell.frame_controller=")
	var battle_idx: int = summary.find("draw.frame.battle_scene=", shell_idx)
	var actor_idx: int = summary.find("01.actors.total=", shell_idx)
	_expect(shell_idx >= 0 and battle_idx >= 0 and actor_idx >= 0, "spike window should include max-hot entries")
	_expect(shell_idx < battle_idx and battle_idx < actor_idx, "spike window max-hot entries should sort by max time")
	logger.samples.clear()
	logger.counters.clear()
	logger.record_value_sample("draw.shell.frame_controller", 9000)
	logger.record_value_sample("draw.frame.total", 7000)
	logger.record_value_sample("01.actors.total", 2900)
	_expect(logger._build_spike_window_summary() == "", "sub-threshold draw samples should not emit a spike window")


func _verify_physics_monitor_summary() -> void:
	var logger := BattlePerfLogger.new()
	var summary: String = logger._build_physics_monitor_summary()
	_expect(summary.find("phys2d=active=") >= 0, "physics monitor summary should expose active 2D physics body count")
	_expect(summary.find("pairs=") >= 0, "physics monitor summary should expose collision pair count")
	_expect(summary.find("islands=") >= 0, "physics monitor summary should expose island count")
	_expect(summary.find("nodes=total=") >= 0, "physics monitor summary should expose total node count")
	_expect(summary.find("orphans=") >= 0, "physics monitor summary should expose orphan node count")
	_expect(summary.find("objects=") >= 0, "physics monitor summary should expose object count for resource-leak detection")
	_expect(summary.find("resources=") >= 0, "physics monitor summary should expose resource count for resource-leak detection")


func _verify_jetpack_state_label() -> void:
	var logger := BattlePerfLogger.new()
	_expect(logger._build_jetpack_label() == "", "jetpack label should be empty before any frames are observed")
	logger.remember_context({"selected_character_type": "smasher", "viper_jetpack_active": true})
	_expect(logger._build_jetpack_label() == "", "non-viper frames should not contribute to the jetpack label")
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": false})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": true, "viper_jetpack_airborne": true})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true})
	var label: String = logger._build_jetpack_label()
	_expect(label.find("jetpack=thrust:1") >= 0, "jetpack label should count active-thrust frames")
	_expect(label.find("glide:2") >= 0, "jetpack label should count airborne-only (glide) frames")
	_expect(label.find("ground:1") >= 0, "jetpack label should count grounded viper frames")
	logger._reset_jetpack_state_counts()
	_expect(logger._build_jetpack_label() == "", "reset should clear jetpack frame counts between log windows")
	_verify_air_strike_counters()


func _verify_air_strike_counters() -> void:
	var logger := BattlePerfLogger.new()
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": true, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 0.0})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": true, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 18.0})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 15.0})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 12.0})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 0.0})
	logger.remember_context({"selected_character_type": "viper", "viper_jetpack_active": false, "viper_jetpack_airborne": true, "viper_air_strike_flash_timer": 18.0})
	var label: String = logger._build_jetpack_label()
	_expect(label.find("air_strike=hits:2") >= 0, "rising-edge transitions on the flash timer should count as new air strike hits")
	_expect(label.find("post_hit:4") >= 0, "frames with a nonzero flash timer should be counted as post-hit frames")
	logger._reset_jetpack_state_counts()
	_expect(logger._build_jetpack_label() == "", "reset should clear air strike counters as well")
	logger.remember_context({"selected_character_type": "smasher", "viper_air_strike_flash_timer": 18.0})
	_expect(logger._build_jetpack_label() == "", "non-viper frames must not contribute to air strike counters")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
