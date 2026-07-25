extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const Stage7AkamuPlayfieldRenderer := preload("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
const Stage7AkamuActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const CLOUD_BASE_SIZE := Vector2(235.0, 56.0)
const CLOUD_FULL_SIZE := Vector2(741.0, 700.0)
const EXPECTED_ACTOR_ORDER: Array[String] = [
	"underlay",
	"player",
	"boss",
	"commando",
	"overlay",
]

var _failures: Array[String] = []


class Stage7Slice4DrawProbe:
	extends Node2D

	var playfield_renderer: Object = null
	var actor_context: Dictionary = {}
	var draw_count := 0
	var underlay_completed_count := 0
	var overlay_completed_count := 0

	func _draw() -> void:
		draw_count += 1
		if playfield_renderer == null:
			return
		playfield_renderer.draw_underlay(self, actor_context, Vector2.ZERO)
		underlay_completed_count += 1
		# This opaque marker stands in for the actor pass. The cloud must blend
		# over it because draw_overlay runs afterward in the same CanvasItem pass.
		draw_rect(Rect2(Vector2(374.0, 294.0), Vector2(12.0, 12.0)), Color(1.0, 0.0, 1.0, 1.0))
		playfield_renderer.draw_overlay(self, actor_context, Vector2.ZERO)
		overlay_completed_count += 1


class ActorOrderDrawProbe:
	extends Node2D

	var actor_renderer: Object = null
	var actor_context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if actor_renderer != null:
			actor_renderer.draw(self, actor_context)


class OrderedPlayfieldRenderer:
	extends RefCounted

	var _calls: Array[String]

	func _init(calls: Array[String]) -> void:
		_calls = calls

	func draw_underlay(
		canvas: CanvasItem,
		_context: Dictionary,
		_shake_offset: Vector2,
		_perf_logger: Object = null
	) -> void:
		_calls.append("underlay")
		canvas.draw_rect(Rect2(Vector2(2.0, 742.0), Vector2(2.0, 2.0)), Color.WHITE)

	func draw_overlay(
		canvas: CanvasItem,
		_context: Dictionary,
		_shake_offset: Vector2,
		_perf_logger: Object = null
	) -> void:
		_calls.append("overlay")
		canvas.draw_rect(Rect2(Vector2(10.0, 742.0), Vector2(2.0, 2.0)), Color.WHITE)


class OrderedActorRenderer:
	extends RefCounted

	var _calls: Array[String]
	var _role: String
	var _marker_x: float

	func _init(calls: Array[String], role: String, marker_x: float) -> void:
		_calls = calls
		_role = role
		_marker_x = marker_x

	func draw(
		canvas: CanvasItem,
		_context: Dictionary,
		_shake_offset: Vector2,
		_perf_logger: Object = null
	) -> void:
		_calls.append(_role)
		canvas.draw_rect(Rect2(Vector2(_marker_x, 742.0), Vector2(2.0, 2.0)), Color.WHITE)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cloud_state: Object = Stage7AkamuState.new()
	cloud_state.debug_seed_rng(7104)
	_expect(
		cloud_state.debug_start_cloud(_base_context(), {}, true, true),
		"visual fixture should start Cloud Veil"
	)
	_advance(cloud_state, 1.20, _base_context())
	var cloud_actor_context: Dictionary = cloud_state.get_actor_draw_context()
	var cloud_payload: Dictionary = _as_dictionary(
		cloud_actor_context.get("stage7_akamu_cloud", {})
	).duplicate(true)
	_expect(not cloud_payload.is_empty(), "Cloud Veil should publish an active draw payload")
	_expect(
		_as_vector2(cloud_payload.get("logical_size", Vector2.ZERO)).is_equal_approx(CLOUD_BASE_SIZE),
		"Cloud Veil should publish the original 235x56 logical base size"
	)
	_expect(
		float(cloud_payload.get("expand_progress", 0.0)) >= 0.99,
		"visual fixture should reach the fully expanded cloud frame"
	)

	var escape_state: Object = Stage7AkamuState.new()
	escape_state.debug_seed_rng(7105)
	var escape_context: Dictionary = _base_context()
	escape_context["boss_paddle_shrink_scale"] = 0.45
	_expect(
		escape_state.debug_start_escape(escape_context, {}, 0.0, true),
		"visual fixture should start Spirit Escape"
	)
	_advance(escape_state, 0.25, escape_context)
	var escape_actor_context: Dictionary = escape_state.get_actor_draw_context()
	var escape_values: Array = _as_array(
		escape_actor_context.get("stage7_akamu_afterimages", [])
	).duplicate(true)
	var hologram_payload: Dictionary = _as_dictionary(
		escape_actor_context.get("stage7_akamu_hologram", {})
	).duplicate(true)
	_expect(escape_values.size() == 5, "Spirit Escape should publish all five delayed ghosts by 250ms")
	_expect(not hologram_payload.is_empty(), "Spirit Escape should keep its hologram active at 250ms")
	for index in range(escape_values.size()):
		var ghost: Dictionary = _as_dictionary(escape_values[index])
		_expect(str(ghost.get("kind", "")) == "escape", "every Spirit Escape trail payload should use kind=escape")
		_expect(int(ghost.get("index", -1)) == index, "Spirit Escape ghost indices should stay ordered 0..4")
		_expect_close(float(ghost.get("visual_scale", 0.0)), 0.45, "every escape ghost should retain the launch-time dwarf scale")
		# Move only the visual fixture anchors below the cloud footprint so an
		# optional windowed capture can inspect ghosts and hologram independently.
		ghost["center"] = Vector2(80.0 + float(index) * 120.0, 690.0)
		escape_values[index] = ghost
	_expect_close(float(hologram_payload.get("visual_scale", 0.0)), 0.45, "escape hologram should retain the launch-time dwarf scale")
	hologram_payload["center"] = Vector2(380.0, 690.0)
	cloud_payload["center"] = Vector2(380.0, 400.0)

	_verify_cloud_footprint_and_source_contract(cloud_payload)
	_verify_draw_command_source_contract()

	var draw_context := {
		"stage7_akamu_afterimages": escape_values,
		"stage7_akamu_hologram": hologram_payload,
		"stage7_akamu_cloud": cloud_payload,
		"stage7_akamu_clones": [],
		"stage7_akamu_shurikens": [],
		"stage7_akamu_particles": [],
		"stage7_akamu_aura": {},
	}
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var draw_probe := Stage7Slice4DrawProbe.new()
	draw_probe.playfield_renderer = Stage7AkamuPlayfieldRenderer.new()
	draw_probe.actor_context = draw_context
	viewport.add_child(draw_probe)

	var actor_calls: Array[String] = []
	var actor_renderer: Object = Stage7AkamuActorRenderer.new()
	actor_renderer.playfield_renderer = OrderedPlayfieldRenderer.new(actor_calls)
	actor_renderer.player_renderer = OrderedActorRenderer.new(actor_calls, "player", 4.0)
	actor_renderer.boss_renderer = OrderedActorRenderer.new(actor_calls, "boss", 6.0)
	actor_renderer.commando_firearm_renderer = OrderedActorRenderer.new(actor_calls, "commando", 8.0)
	var order_probe := ActorOrderDrawProbe.new()
	order_probe.actor_renderer = actor_renderer
	order_probe.actor_context = {"shake_offset": Vector2.ZERO}
	viewport.add_child(order_probe)

	draw_probe.queue_redraw()
	order_probe.queue_redraw()
	for _frame in range(4):
		await process_frame

	_expect(draw_probe.draw_count > 0, "Slice 4 visual payloads should execute inside a real CanvasItem _draw pass")
	_expect(
		draw_probe.underlay_completed_count == draw_probe.draw_count,
		"escape ghosts and hologram should complete the underlay draw pass"
	)
	_expect(
		draw_probe.overlay_completed_count == draw_probe.draw_count,
		"Cloud Veil should complete the foreground overlay draw pass"
	)
	_expect(order_probe.draw_count > 0, "actor orchestrator should execute inside a real CanvasItem _draw pass")
	_verify_actor_order(actor_calls)
	_verify_pixels_when_available(viewport)

	viewport.queue_free()
	if _failures.is_empty():
		print("stage7_akamu_slice4_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cloud_footprint_and_source_contract(cloud_payload: Dictionary) -> void:
	var logical_size: Vector2 = _as_vector2(cloud_payload.get("logical_size", Vector2.ZERO))
	var side_expand: float = Stage7AkamuPlayfieldRenderer.CLOUD_EXPAND_SIDE
	var top_expand: float = Stage7AkamuPlayfieldRenderer.CLOUD_EXPAND_TOP
	var full_size := logical_size + Vector2(
		side_expand * 2.0,
		side_expand * 2.0 + top_expand
	)
	_expect(full_size.is_equal_approx(CLOUD_FULL_SIZE), "fully expanded Cloud Veil footprint should be 741x700")

	# 원본 파리티: 연막 타원의 중심은 payload(착지) 중심 그 자체이고, 풋프린트의
	# 위쪽 138px는 파티클 헤드룸이다. 타원 크기는 풋프린트의 85% x 65%.
	var renderer: Object = Stage7AkamuPlayfieldRenderer.new()
	var profile: Dictionary = renderer.get_debug_cloud_draw_profile(cloud_payload)
	var payload_center: Vector2 = _as_vector2(cloud_payload.get("center", Vector2.ZERO))
	_expect(
		_as_vector2(profile.get("ellipse_center", Vector2.ZERO)).is_equal_approx(payload_center),
		"Cloud Veil smoke ellipse should stay centered on the landing payload center (legacy parity)"
	)
	_expect(
		_as_vector2(profile.get("full_size", Vector2.ZERO)).is_equal_approx(CLOUD_FULL_SIZE),
		"Cloud Veil draw profile should expose the 741x700 footprint"
	)
	_expect(
		_as_vector2(profile.get("ellipse_size", Vector2.ZERO)).is_equal_approx(
			Vector2(CLOUD_FULL_SIZE.x * 0.85, CLOUD_FULL_SIZE.y * 0.65)
		),
		"fully expanded Cloud Veil ellipse should be 85% x 65% of the footprint"
	)
	_expect(str(profile.get("mode", "")) == "sustained", "fully expanded Cloud Veil should report the sustained mode")
	var fill_value: Variant = profile.get("fill_color", null)
	_expect(
		fill_value is Color and (fill_value as Color).is_equal_approx(
			Color(45.0 / 255.0, 38.0 / 255.0, 70.0 / 255.0)
		),
		"Cloud Veil fill should keep the legacy dark-violet (45,38,70) palette"
	)


func _verify_draw_command_source_contract() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd"
	)
	var underlay_source := _source_section(source, "func draw_underlay(", "func draw_overlay(")
	var overlay_source := _source_section(source, "func draw_overlay(", "func get_asset_status(")
	var cloud_source := _source_section(source, "func _draw_cloud(", "func _draw_aura(")
	var escape_source := _source_section(source, "func _draw_afterimage(", "func _draw_particle(")
	_expect(
		underlay_source.find("stage7_akamu_afterimages") >= 0 \
			and underlay_source.find("stage7_akamu_hologram") >= 0,
		"underlay should consume both Spirit Escape ghosts and hologram payloads"
	)
	_expect(
		underlay_source.find("stage7_akamu_cloud") < 0 \
			and overlay_source.find("stage7_akamu_cloud") >= 0,
		"Cloud Veil should be consumed only by the foreground overlay pass"
	)
	_expect(
		cloud_source.find("_draw_ellipse") >= 0 \
			and cloud_source.find("canvas.draw_circle") >= 0,
		"Cloud Veil overlay should submit the legacy smoke ellipse plus bounded particle circles"
	)
	_expect(
		escape_source.find("afterimage.get(\"kind\"") >= 0 \
			and escape_source.find("== \"escape\"") >= 0 \
			and escape_source.find("visual_scale") >= 0 \
			and escape_source.find("* visual_scale") >= 0 \
			and escape_source.find("canvas.draw_rect") >= 0 \
			and escape_source.find("canvas.draw_circle") >= 0 \
			and escape_source.find("canvas.draw_line") >= 0,
		"Spirit Escape underlay should route escape payloads into silhouette draw commands"
	)


func _verify_actor_order(calls: Array[String]) -> void:
	_expect(calls.size() >= EXPECTED_ACTOR_ORDER.size(), "actor orchestrator should emit one complete five-pass sequence")
	if calls.size() < EXPECTED_ACTOR_ORDER.size():
		return
	_expect(
		calls.size() % EXPECTED_ACTOR_ORDER.size() == 0,
		"each actor draw should emit exactly one five-pass sequence"
	)
	for offset in range(0, calls.size(), EXPECTED_ACTOR_ORDER.size()):
		if offset + EXPECTED_ACTOR_ORDER.size() > calls.size():
			break
		for index in range(EXPECTED_ACTOR_ORDER.size()):
			_expect(
				calls[offset + index] == EXPECTED_ACTOR_ORDER[index],
				"actor pass order should remain underlay -> player -> boss -> commando -> overlay"
			)


func _verify_pixels_when_available(viewport: SubViewport) -> void:
	if OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0:
		return
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "windowed Slice 4 QA should capture the viewport")
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var cloud_over_actor: Color = image.get_pixel(380, 300)
	_expect(
		cloud_over_actor.a > 0.95 and cloud_over_actor.r < 0.80 and cloud_over_actor.g > 0.02,
		"foreground cloud should composite over the opaque magenta actor marker"
	)
	_expect(image.get_pixel(80, 710).a > 0.08, "escape ghost 0 should render through the underlay draw pass")
	_expect(image.get_pixel(380, 710).a > 0.08, "escape hologram should render through the underlay draw pass")


func _source_section(source: String, start_marker: String, end_marker: String) -> String:
	var start_index: int = source.find(start_marker)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_marker, start_index + start_marker.length())
	if end_index < 0:
		return source.substr(start_index)
	return source.substr(start_index, end_index - start_index)


func _advance(state: Object, duration_sec: float, context: Dictionary) -> void:
	var remaining: float = duration_sec
	while remaining > 0.000001:
		var step: float = minf(0.05, remaining)
		state.update(step, context)
		remaining -= step


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 20.0,
		"last_hit_by": "player",
	}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
