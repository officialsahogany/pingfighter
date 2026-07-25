extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const Stage7AkamuPlayfieldRenderer := preload("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
const Stage7AkamuBossActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")

const VIEW_SIZE := Vector2i(1000, 750)

var _failures: Array[String] = []


class Stage7Slice3DrawProbe:
	extends Node2D

	var playfield_renderer: Object = null
	var boss_renderer: Object = null
	var hud_renderer: Object = null
	var actor_context: Dictionary = {}
	var hud_context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if playfield_renderer != null:
			playfield_renderer.draw(self, actor_context, Vector2.ZERO)
		if boss_renderer != null:
			boss_renderer.draw(self, actor_context, Vector2.ZERO)
		if hud_renderer != null:
			hud_renderer.draw(self, hud_context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(200.0)
	state.debug_set_awakened(true)
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	_advance(state, 0.6, _state_context())
	state.set_boss_ball_intangible_source("visual_probe", true)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := Stage7Slice3DrawProbe.new()
	probe.playfield_renderer = Stage7AkamuPlayfieldRenderer.new()
	probe.boss_renderer = Stage7AkamuBossActorRenderer.new()
	probe.hud_renderer = Stage7AkamuBossSkillHudRenderer.new()
	probe.actor_context = _actor_context(state)
	probe.hud_context = _hud_context(state)
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame in range(4):
		await process_frame

	_expect(probe.draw_count > 0, "Slice 3 playfield, boss, and HUD renderers should execute inside a real CanvasItem draw pass")
	var clones: Array = probe.actor_context.get("stage7_akamu_clones", [])
	_expect(clones.size() == 2, "visual draw payload should contain both active clones")
	_expect(float((clones[0] as Dictionary).get("alpha", 0.0)) > 0.7, "fully emerged clone payload should be visibly opaque")
	var clone_card: Dictionary = _find_skill(probe.hud_context.get("stage7_boss_skill_hud_skills", []), "stage7_clone")
	_expect(int(clone_card.get("active_count", 0)) == 2, "rendered clone card should receive the ×2 label payload")
	_verify_anchor_pixels_when_available(viewport)

	var collision_context: Dictionary = _state_context()
	collision_context["last_hit_by"] = "player"
	_expect(state.resolve_ball_collision({
		"previous_ball_pos": Vector2(290.0, 320.0),
		"ball_pos": Vector2(290.0, 120.0),
		"ball_vel": Vector2(0.0, -12.0),
	}, collision_context), "visual dying pass should start from a real clone collision")
	_advance(state, 0.35, collision_context)
	probe.actor_context = _actor_context(state)
	probe.hud_context = _hud_context(state)
	var draw_count_before: int = probe.draw_count
	probe.queue_redraw()
	for _frame in range(3):
		await process_frame
	_expect(probe.draw_count > draw_count_before, "dying clone state should execute a second real draw pass")
	var dying_count := 0
	for clone_value in probe.actor_context.get("stage7_akamu_clones", []):
		if clone_value is Dictionary and str((clone_value as Dictionary).get("phase", "")) == "dying":
			dying_count += 1
			_expect(float((clone_value as Dictionary).get("death_progress", 0.0)) > 0.45, "dying draw payload should be midway through its dissolve")
	_expect(dying_count == 1, "visual pass should contain exactly one dissolving clone")

	viewport.queue_free()
	if _failures.is_empty():
		print("stage7_akamu_slice3_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _actor_context(state: Object) -> Dictionary:
	var context: Dictionary = state.get_actor_draw_context().duplicate(true)
	context.merge({
		"current_stage": 7,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"boss_paddle_shrink_scale": 1.0,
	}, true)
	return context


func _hud_context(state: Object) -> Dictionary:
	var context: Dictionary = state.get_hud_context().duplicate(true)
	context.merge({
		"current_stage": 7,
		"view_size": Vector2(VIEW_SIZE),
		"game_offset": Vector2(120.0, 0.0),
		"game_size": Vector2(760.0, 750.0),
		"time_seconds": 1.25,
	}, true)
	return context


func _state_context() -> Dictionary:
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


func _advance(state: Object, duration_sec: float, context: Dictionary) -> void:
	var remaining: float = duration_sec
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.update(step, context)
		remaining -= step


func _verify_anchor_pixels_when_available(viewport: SubViewport) -> void:
	if OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0:
		return
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "windowed visual QA should capture the Slice 3 viewport")
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	# At full emergence the left clone center is x=290. Its 12px visual offset
	# extends the 96px body through y=260; y=255 would be empty with the old,
	# incorrectly high anchor.
	_expect(image.get_pixel(290, 255).a > 0.10, "clone placeholder should render at the boss-aligned +12px visual anchor")


func _find_skill(value: Variant, skill_id: String) -> Dictionary:
	if not (value is Array):
		return {}
	for entry_value in value:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == skill_id:
			return entry_value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
