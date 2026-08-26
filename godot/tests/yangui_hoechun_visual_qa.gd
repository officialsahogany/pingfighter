extends SceneTree

const YanguiHoechunRuntime := preload("res://scripts/items/mythic_item_yangui_hoechun_runtime.gd")
const YanguiHoechunFieldRenderer := preload("res://scripts/items/mythic_item_yangui_hoechun_field_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const STEP_SEC := 1.0 / 120.0
const CAST_CAPTURE_SEC := 0.35
const OUTPUT_DIR := "res://.godot/codex_artifacts/yangui_hoechun_wave_redesign"
const BENCHMARK_ITERATIONS := 1
const BENCHMARK_SAMPLES := 15
const THREE_WAVE_DRAW_BUDGET_USEC := 1750.0

var _failures: Array[String] = []
var _cyan_pixel_total := 0
var _cyan_rgb_sum := Vector3.ZERO


class FakeAudioRouter:
	func play_yangui_hoechun_reflect_audio(_runtime: Object, _registry: Object, _speed: float) -> void:
		pass


class FakeRuntime:
	var audio_router := FakeAudioRouter.new()

	func _safe_owner_get(owner: Object, property_name: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(property_name)
		return fallback if value == null else value

	func _get_vector2(value: Variant) -> Vector2:
		return value if value is Vector2 else Vector2.ZERO


class FakeOwner:
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_radius := 14.3
	var ball_size := 28.6


class FakeRegistry:
	pass


class EffectProbe:
	extends Node2D

	var renderer: Object = YanguiHoechunFieldRenderer.new()
	var context: Dictionary = {}
	var origin_x := 380.0
	var draw_effect_enabled := true
	var draw_calls := 0

	func _draw() -> void:
		draw_calls += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("#11161d"), true)
		draw_rect(Rect2(Vector2(0.0, 570.0), Vector2(760.0, 180.0)), Color("#2d2a24"), true)
		for y in [604.0, 646.0, 688.0, 730.0]:
			draw_rect(Rect2(Vector2(0.0, y), Vector2(760.0, 2.0)), Color(0.24, 0.22, 0.18, 0.46), true)
		for x in range(0, VIEW_SIZE.x, 76):
			draw_rect(Rect2(Vector2(float(x), 570.0), Vector2(2.0, 180.0)), Color(0.20, 0.19, 0.16, 0.32), true)
		var player_rect := Rect2(Vector2(origin_x - 77.5, 690.0), Vector2(155.0, 50.0))
		draw_rect(player_rect.grow(5.0), Color(0.36, 0.25, 0.08, 0.55), true)
		draw_rect(player_rect, Color("#202733"), true)
		draw_rect(Rect2(player_rect.position + Vector2(8.0, 7.0), player_rect.size - Vector2(16.0, 14.0)), Color("#d5ad34"), true)
		if draw_effect_enabled:
			renderer.draw_effect(self, Vector2.ZERO, context)


class BenchmarkProbe:
	extends Node2D

	signal sample_ready(average_usec: float)

	var renderer: Object = YanguiHoechunFieldRenderer.new()
	var context: Dictionary = {}
	var iterations := 1
	var pending := false

	func start_sample(next_context: Dictionary, next_iterations: int) -> void:
		context = next_context
		iterations = maxi(1, next_iterations)
		pending = true
		queue_redraw()

	func _draw() -> void:
		if not pending:
			return
		var started_usec := Time.get_ticks_usec()
		for _iteration in range(iterations):
			renderer.draw_effect(self, Vector2.ZERO, context)
		var average_usec := float(Time.get_ticks_usec() - started_usec) / float(iterations)
		pending = false
		call_deferred("_emit_sample", average_usec)

	func _emit_sample(average_usec: float) -> void:
		sample_ready.emit(average_usec)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("Yangui Hoechun pixel QA requires a Vulkan window")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var timings := {}
	for fixture in [
		{"name": "center", "origin_x": 380.0, "wall_side": "both"},
		{"name": "left_corner", "origin_x": 77.5, "wall_side": "right"},
		{"name": "right_corner", "origin_x": 682.5, "wall_side": "left"},
	]:
		var name := str(fixture["name"])
		var origin_x := float(fixture["origin_x"])
		var contexts := _build_runtime_capture_contexts(origin_x)
		timings[name] = contexts.get("wall_time_sec", -1.0)
		await _capture_and_seal(name + "_cast", origin_x, contexts.get("cast_context", {}), "none")
		await _capture_and_seal(name + "_wall", origin_x, contexts.get("wall_context", {}), str(fixture["wall_side"]))
	var benchmark := await _run_draw_benchmark()
	if _cyan_pixel_total <= 0:
		_fail("Yangui visual QA found no effect-isolated cyan-dominant pixels")
	var cyan_mean := _cyan_rgb_sum / float(maxi(1, _cyan_pixel_total))
	if _failures.is_empty():
		print("[YanguiVisualTimingSeal] center=%.3fs left_corner=%.3fs right_corner=%.3fs" % [
			float(timings["center"]),
			float(timings["left_corner"]),
			float(timings["right_corner"]),
		])
		print("[YanguiCyanDominanceSeal] pixels=%d mean_rgb=(%.3f,%.3f,%.3f) red_gap_min=0.080" % [
			_cyan_pixel_total,
			cyan_mean.x,
			cyan_mean.y,
			cyan_mean.z,
		])
		print("[YanguiDrawBudgetSeal] one_wave_median_usec=%.3f three_wave_median_usec=%.3f limit_usec=%.3f iterations=%d samples=%d" % [
			float(benchmark["one_wave_usec"]),
			float(benchmark["three_wave_usec"]),
			THREE_WAVE_DRAW_BUDGET_USEC,
			BENCHMARK_ITERATIONS,
			BENCHMARK_SAMPLES,
		])
		print("[YanguiVisualPaletteSeal] captures=6 gold=true cyan_dominant=true bright_core=true effect_isolated=true")
		print("yangui_hoechun_visual_qa: captures=6")
		print("yangui_hoechun_visual_qa: ok")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	_finish()


func _finish() -> void:
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		push_error("yangui_hoechun_visual_qa: failed")
		quit(1)
		return
	quit(0)


func _fail(message: String) -> void:
	_failures.append(message)


func _build_runtime_capture_contexts(origin_x: float) -> Dictionary:
	var runtime: Object = YanguiHoechunRuntime.new()
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	runtime.call("_start_wave", Vector2(origin_x, 715.0))
	var elapsed := 0.0
	while elapsed + STEP_SEC * 0.5 < CAST_CAPTURE_SEC:
		runtime.call("_advance_effect", fake_runtime, owner, registry, STEP_SEC)
		elapsed += STEP_SEC
	var cast_context: Dictionary = runtime.get_draw_context().duplicate(true)
	var wall_context := {}
	var wall_time_sec := -1.0
	while elapsed < 6.0:
		runtime.call("_advance_effect", fake_runtime, owner, registry, STEP_SEC)
		elapsed += STEP_SEC
		var debug_contexts: Array[Dictionary] = runtime.get_debug_wave_contexts()
		if debug_contexts.is_empty():
			continue
		var debug_context: Dictionary = debug_contexts[0]
		if bool(debug_context["left_reached_wall"]) and bool(debug_context["right_reached_wall"]):
			wall_context = runtime.get_draw_context().duplicate(true)
			wall_time_sec = elapsed
			break
	if wall_context.is_empty():
		_fail("Yangui visual fixture did not reach both walls from x=%.1f" % origin_x)
	return {
		"cast_context": cast_context,
		"wall_context": wall_context,
		"wall_time_sec": wall_time_sec,
	}


func _capture_and_seal(name: String, origin_x: float, context: Dictionary, wall_side: String) -> void:
	if context.is_empty():
		_fail("Yangui visual capture context was empty: " + name)
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var probe := EffectProbe.new()
	probe.context = context
	probe.origin_x = origin_x
	viewport.add_child(probe)
	probe.draw_effect_enabled = false
	var baseline := await _capture_probe_image(probe, viewport)
	probe.draw_effect_enabled = true
	var image := await _capture_probe_image(probe, viewport)
	if baseline == null or baseline.is_empty() or image == null or image.is_empty():
		_fail("Yangui visual capture was empty: " + name)
		viewport.queue_free()
		await process_frame
		return
	var pixel_counts := _count_effect_pixels(image, baseline, wall_side)
	if int(pixel_counts["gold"]) < 180:
		_fail("Yangui capture lacks effect-isolated gold ground mass: " + name)
	if int(pixel_counts["cyan_dominant"]) < 80:
		_fail("Yangui capture lacks strongly cyan-dominant crescent pixels: " + name)
	if int(pixel_counts["bright_core"]) < 30:
		_fail("Yangui capture lacks an effect-isolated filled bright core: " + name)
	if wall_side != "none" and int(pixel_counts["wall"]) < 2:
		_fail("Yangui capture did not visibly touch the requested wall: " + name)
	var capture_path := OUTPUT_DIR + "/" + name + ".png"
	if image.save_png(capture_path) != OK:
		_fail("Yangui visual capture save failed: " + capture_path)
	var cyan_count := int(pixel_counts["cyan_dominant"])
	var cyan_sum: Vector3 = pixel_counts["cyan_rgb_sum"]
	_cyan_pixel_total += cyan_count
	_cyan_rgb_sum += cyan_sum
	var cyan_mean := cyan_sum / float(maxi(1, cyan_count))
	print("[YanguiPixelSeal] name=%s gold=%d cyan_dominant=%d cyan_mean=(%.3f,%.3f,%.3f) bright_core=%d wall_pixels=%d" % [
		name,
		int(pixel_counts["gold"]),
		cyan_count,
		cyan_mean.x,
		cyan_mean.y,
		cyan_mean.z,
		int(pixel_counts["bright_core"]),
		int(pixel_counts["wall"]),
	])
	viewport.queue_free()
	await process_frame


func _capture_probe_image(probe: EffectProbe, viewport: SubViewport) -> Image:
	var before_calls := probe.draw_calls
	probe.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	if probe.draw_calls <= before_calls:
		_fail("Yangui visual probe did not redraw")
	return viewport.get_texture().get_image()


func _count_effect_pixels(image: Image, baseline: Image, wall_side: String) -> Dictionary:
	var gold := 0
	var cyan_dominant := 0
	var bright_core := 0
	var wall := 0
	var cyan_rgb_sum := Vector3.ZERO
	for y in range(570, VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var color := image.get_pixel(x, y)
			var reference := baseline.get_pixel(x, y)
			var effect_delta := absf(color.r - reference.r) + absf(color.g - reference.g) + absf(color.b - reference.b)
			if effect_delta < 0.12:
				continue
			var is_gold := color.r > 0.48 and color.g > 0.32 and color.g < 0.90 and color.b < 0.36 and color.r > color.b * 1.8
			var is_cyan := color.b > 0.64 and color.g > 0.70 and color.b - color.r > 0.10 and color.g - color.r > 0.08
			var is_bright := color.r > 0.88 and color.g > 0.88 and color.b > 0.82
			if is_gold:
				gold += 1
			if is_cyan:
				cyan_dominant += 1
				cyan_rgb_sum += Vector3(color.r, color.g, color.b)
			if is_bright:
				bright_core += 1
			if (
				(wall_side == "left" and x <= 3)
				or (wall_side == "right" and x >= VIEW_SIZE.x - 4)
				or (wall_side == "both" and (x <= 3 or x >= VIEW_SIZE.x - 4))
			):
				wall += 1
	return {
		"gold": gold,
		"cyan_dominant": cyan_dominant,
		"cyan_rgb_sum": cyan_rgb_sum,
		"bright_core": bright_core,
		"wall": wall,
	}


func _run_draw_benchmark() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := BenchmarkProbe.new()
	viewport.add_child(probe)
	var one_wave_context := _build_benchmark_context(1)
	var three_wave_context := _build_benchmark_context(3)
	await _benchmark_sample(probe, three_wave_context, 20)
	var one_wave_samples: Array[float] = []
	var three_wave_samples: Array[float] = []
	for _sample_index in range(BENCHMARK_SAMPLES):
		one_wave_samples.append(await _benchmark_sample(probe, one_wave_context, BENCHMARK_ITERATIONS))
		three_wave_samples.append(await _benchmark_sample(probe, three_wave_context, BENCHMARK_ITERATIONS))
	one_wave_samples.sort()
	three_wave_samples.sort()
	var one_wave_median := one_wave_samples[one_wave_samples.size() / 2]
	var three_wave_median := three_wave_samples[three_wave_samples.size() / 2]
	if three_wave_median > THREE_WAVE_DRAW_BUDGET_USEC:
		_fail("Yangui three-wave draw cost %.3fus exceeds %.3fus budget" % [three_wave_median, THREE_WAVE_DRAW_BUDGET_USEC])
	viewport.queue_free()
	await process_frame
	return {"one_wave_usec": one_wave_median, "three_wave_usec": three_wave_median}


func _benchmark_sample(probe: BenchmarkProbe, context: Dictionary, iterations: int) -> float:
	probe.start_sample(context, iterations)
	var result: Variant = await probe.sample_ready
	return float(result)


func _build_benchmark_context(wave_count: int) -> Dictionary:
	var runtime: Object = YanguiHoechunRuntime.new()
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	for origin_x in [280.0, 380.0, 480.0].slice(0, wave_count):
		runtime.call("_start_wave", Vector2(float(origin_x), 715.0))
	runtime.call("_advance_effect", fake_runtime, owner, registry, CAST_CAPTURE_SEC)
	return runtime.get_draw_context().duplicate(true)
