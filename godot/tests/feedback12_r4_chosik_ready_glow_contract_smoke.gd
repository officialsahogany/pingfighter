extends SceneTree

const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")

const TEST_SKILL_ID := "feedback12_r4_ready_probe"

var _failures: Array[String] = []


class FakeSocketRenderer:
	extends RefCounted

	var ready_glow_calls := 0
	var legacy_ready_ring_calls := 0

	func draw_socket(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_socket_overlap: float,
		_bg_color: Color,
		_border_color: Color
	) -> void:
		pass

	func draw_activation_flash(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_scale_factor: float,
		_progress: float,
		_skill_color: Color
	) -> void:
		pass

	func draw_ready_glow(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		_time_seconds: float,
		_phase_offset: float,
		_color: Color
	) -> void:
		ready_glow_calls += 1

	# Retain the legacy signature only so the pre-fix production call becomes a
	# deliberate assertion failure instead of aborting this RED smoke early.
	func draw_ready_ring(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		_time_seconds: float,
		_phase_offset: float,
		_color: Color
	) -> void:
		legacy_ready_ring_calls += 1


class FakeCooldownRenderer:
	extends RefCounted

	var draw_calls := 0
	var ratios: Array[float] = []

	func draw(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		cooldown_ratio: float,
		_pillar_drawer: Variant,
		_static_hud_lod: bool = false
	) -> void:
		draw_calls += 1
		ratios.append(cooldown_ratio)


class FakeSymbolRenderer:
	extends RefCounted

	var active_states: Array[bool] = []

	func draw(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_skill_name: String,
		_color: Color,
		is_active: bool
	) -> void:
		active_states.append(is_active)


func _init() -> void:
	_verify_layout_preserves_production_overrides()
	_verify_ready_override_controls_the_live_slot_path()
	_verify_cooldown_override_controls_the_live_slot_path()
	_verify_ready_glow_uses_fill_only_primitives()

	if _failures.is_empty():
		print("feedback12_r4_chosik_ready_glow_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_layout_preserves_production_overrides() -> void:
	var layout := Stage1PillarUiLayout.new()
	var context: Dictionary = layout.build_skill_orb_context(_build_source_context(false, 0.625), null)
	var ready_overrides: Dictionary = _get_dict(context.get("skill_ready_overrides", {}))
	var cooldown_ratios: Dictionary = _get_dict(context.get("skill_cooldown_remaining_ratios", {}))
	_expect(
		ready_overrides.has(TEST_SKILL_ID),
		"production skill-orb layout must preserve an explicit false ready override"
	)
	_expect(
		not bool(ready_overrides.get(TEST_SKILL_ID, true)),
		"production skill-orb layout must preserve the false ready value without defaulting it to ready"
	)
	_expect(
		cooldown_ratios.has(TEST_SKILL_ID),
		"production skill-orb layout must preserve per-skill cooldown ratios"
	)
	_expect(
		is_equal_approx(float(cooldown_ratios.get(TEST_SKILL_ID, -1.0)), 0.625),
		"production skill-orb layout must preserve the exact cooldown ratio passed by the scene drawer"
	)


func _verify_ready_override_controls_the_live_slot_path() -> void:
	var ready_result: Dictionary = _draw_production_slot(true, 0.0)
	var blocked_result: Dictionary = _draw_production_slot(false, 0.0)
	var ready_socket: Object = ready_result.get("socket", null)
	var blocked_socket: Object = blocked_result.get("socket", null)
	var ready_symbol: Object = ready_result.get("symbol", null)
	var blocked_symbol: Object = blocked_result.get("symbol", null)

	_expect(ready_socket.ready_glow_calls == 1, "ready=true must draw exactly one fill-only ready glow")
	_expect(blocked_socket.ready_glow_calls == 0, "ready=false must not draw the ready glow")
	_expect(ready_socket.legacy_ready_ring_calls == 0, "ready=true must not call the retired closed-ring primitive")
	_expect(blocked_socket.legacy_ready_ring_calls == 0, "ready=false must not call the retired closed-ring primitive")
	_expect(
		ready_symbol.active_states.size() == 1 and bool(ready_symbol.active_states[0]),
		"ready=true must keep the production slot symbol active"
	)
	_expect(
		blocked_symbol.active_states.size() == 1 and not bool(blocked_symbol.active_states[0]),
		"ready=false must darken the production slot symbol even when Ki and base cooldown are ready"
	)


func _verify_cooldown_override_controls_the_live_slot_path() -> void:
	var result: Dictionary = _draw_production_slot(true, 0.625)
	var socket: Object = result.get("socket", null)
	var cooldown: Object = result.get("cooldown", null)
	var symbol: Object = result.get("symbol", null)
	_expect(cooldown.draw_calls == 1, "a positive production cooldown override must reach the slot cooldown renderer")
	_expect(
		cooldown.ratios.size() == 1 and is_equal_approx(float(cooldown.ratios[0]), 0.625),
		"the slot cooldown renderer must receive the exact production override ratio"
	)
	_expect(socket.ready_glow_calls == 0, "a cooldown-blocked slot must not draw the ready glow")
	_expect(socket.legacy_ready_ring_calls == 0, "a cooldown-blocked slot must not call the retired closed-ring primitive")
	_expect(
		symbol.active_states.size() == 1 and not bool(symbol.active_states[0]),
		"a positive cooldown override must darken the production slot"
	)


func _verify_ready_glow_uses_fill_only_primitives() -> void:
	var socket_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_socket_renderer.gd")
	var slot_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
	var ready_body: String = _extract_function_body(socket_source, "func draw_ready_glow(")
	var compact_body: String = _compact_whitespace(ready_body)

	_expect(slot_source.find("socket_renderer.draw_ready_glow(") >= 0, "live slots must call draw_ready_glow for ready feedback")
	_expect(slot_source.find("socket_renderer.draw_ready_ring(") < 0, "live slots must retire the closed ready-ring call")
	_expect(not ready_body.is_empty(), "socket renderer must own a dedicated draw_ready_glow primitive")
	_expect(
		ready_body.find("draw_circle(") >= 0 or ready_body.find("draw_colored_polygon(") >= 0,
		"ready glow must be composed from filled circles or filled polygons"
	)
	for forbidden_token in ["draw_arc(", "TAU", "draw_line(", "draw_polyline(", "draw_multiline(", "draw_dashed_line("]:
		_expect(
			ready_body.find(forbidden_token) < 0,
			"ready glow must not use closed-ring, outline, or dash primitive: %s" % forbidden_token
		)
	_expect(compact_body.find(", false") < 0, "ready glow must not request an unfilled circle outline")


func _draw_production_slot(ready: bool, cooldown_ratio: float) -> Dictionary:
	var layout := Stage1PillarUiLayout.new()
	var orb_context: Dictionary = layout.build_skill_orb_context(
		_build_source_context(ready, cooldown_ratio),
		null
	)
	var renderer := SmasherSkillOrbRenderer.new()
	var socket := FakeSocketRenderer.new()
	var cooldown := FakeCooldownRenderer.new()
	var symbol := FakeSymbolRenderer.new()
	renderer.slot_renderer.socket_renderer = socket
	renderer.slot_renderer.cooldown_renderer = cooldown
	renderer.slot_renderer.symbol_renderer = symbol
	var canvas := Node2D.new()
	renderer.draw_orbs(canvas, Vector2.ZERO, 55.0, 0.25, 1.0, orb_context)
	canvas.free()
	return {
		"context": orb_context,
		"socket": socket,
		"cooldown": cooldown,
		"symbol": symbol,
	}


func _build_source_context(ready: bool, cooldown_ratio: float) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"pillar_hud_static_lod": false,
		"special_gauge": 100.0,
		"skill_ready_overrides": {TEST_SKILL_ID: ready},
		"skill_cooldown_remaining_ratios": {TEST_SKILL_ID: cooldown_ratio},
		"skill_config_snapshot": {
			"max_slots": 1,
			"equipped_skills": [TEST_SKILL_ID],
			"skill_costs": {TEST_SKILL_ID: 20.0},
			"skill_colors": {TEST_SKILL_ID: Color(0.32, 0.82, 0.64)},
			"cooldown_seconds": {TEST_SKILL_ID: 0.0},
		},
	}


func _extract_function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + signature.length())
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _compact_whitespace(value: String) -> String:
	var compact := value.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	return compact


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
