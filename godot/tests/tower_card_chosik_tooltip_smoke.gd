extends SceneTree

const SmasherSkillOrbTooltipRenderer := preload(
	"res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(2020.0, 1246.0)
const FALLBACK_VIEW_SIZE := Vector2(760.0, 750.0)

var _failures: Array[String] = []


class FakeSkillConfig:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"max_slots": 5,
			"equipped_skills": [],
			"skill_costs": {"ghost_shot": 20.0},
			"skill_colors": {"ghost_shot": Color(0.72, 0.38, 0.92)},
			"cooldown_seconds": {"ghost_shot": 8.0},
			"skill_data": {
				"ghost_shot": {
					"name": "ghost_shot",
					"korean": "허공환영",
					"description": "공을 받아친 뒤 허상을 남겨 적을 기만합니다.",
					"how_to_use": "공격 방향과 함께 발동",
					"effect_type": "ghost_shot",
					"color": Color(0.72, 0.38, 0.92),
					"cost": 20.0,
					"cooldown": 8.0,
				},
			},
		}


class FakeRegistry:
	extends RefCounted

	var skill_config := FakeSkillConfig.new()

	func get_instance(key: String) -> Object:
		if key == "smasher_skill_config":
			return skill_config
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	await process_frame
	var canvas := Node2D.new()
	root.add_child(canvas)
	await process_frame

	var renderer: Object = SmasherSkillOrbTooltipRenderer.new()
	var registry := FakeRegistry.new()
	var actual_view_size: Vector2 = canvas.get_viewport_rect().size
	_expect(actual_view_size.is_equal_approx(VIEW_SIZE), "test viewport must materialize at the 2020x1246 acceptance size")
	_verify_grt_044_viewport_precedence(renderer, canvas, actual_view_size)
	_verify_start_and_reward_chosik_states(renderer, registry, canvas, actual_view_size)
	_verify_single_owner_wiring()

	canvas.queue_free()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("tower_card_chosik_tooltip_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_grt_044_viewport_precedence(renderer: Object, canvas: CanvasItem, actual_view_size: Vector2) -> void:
	var live_size: Vector2 = renderer.resolve_card_tooltip_view_size(canvas, FALLBACK_VIEW_SIZE)
	_expect(live_size.is_equal_approx(actual_view_size), "GRT-044: in-tree card tooltip must use canvas.get_viewport_rect().size")
	_expect(not live_size.is_equal_approx(FALLBACK_VIEW_SIZE), "GRT-044 reverse leg: in-tree card tooltip must reject the supplied game-size fallback")
	var detached_canvas := Node2D.new()
	var fallback_size: Vector2 = renderer.resolve_card_tooltip_view_size(detached_canvas, FALLBACK_VIEW_SIZE)
	_expect(fallback_size.is_equal_approx(FALLBACK_VIEW_SIZE), "pre-tree card tooltip must retain the supplied deterministic fallback")
	detached_canvas.free()


func _verify_start_and_reward_chosik_states(
	renderer: Object,
	registry: Object,
	canvas: CanvasItem,
	view_size: Vector2
) -> void:
	var card_rects: Array[Rect2] = [
		Rect2(Vector2(500.0, 310.0), Vector2(300.0, 320.0)),
		Rect2(Vector2(860.0, 310.0), Vector2(300.0, 320.0)),
		Rect2(Vector2(1220.0, 310.0), Vector2(300.0, 320.0)),
	]
	var scene_context := {
		"selected_character_type": "smasher",
		"special_gauge": 45.0,
	}
	var start_state: Dictionary = renderer.build_card_tooltip_state(
		canvas,
		registry,
		FALLBACK_VIEW_SIZE,
		scene_context,
		{
			"id": "start_chosik_probe",
			"start_card_kind": "chosik",
			"unlocks_skill": "ghost_shot",
			"is_skill_manual": true,
		},
		card_rects[0],
		card_rects,
		card_rects[0].get_center()
	)
	_expect(not start_state.is_empty(), "start Chosik card hover must resolve the existing orb tooltip owner")
	_verify_tooltip_rect(start_state, card_rects, view_size, "start")

	var reward_state: Dictionary = renderer.build_card_tooltip_state(
		canvas,
		registry,
		FALLBACK_VIEW_SIZE,
		scene_context,
		{
			"id": "reward_vision_probe",
			"reward_pick_kind": "vision",
			"unlocks_skill": "ghost_shot",
			"is_skill_manual": true,
		},
		card_rects[2],
		card_rects,
		card_rects[2].get_center()
	)
	_expect(not reward_state.is_empty(), "reward Chosik card hover must resolve the existing orb tooltip owner")
	_verify_tooltip_rect(reward_state, card_rects, view_size, "reward")

	var mugong_state: Dictionary = renderer.build_card_tooltip_state(
		canvas,
		registry,
		FALLBACK_VIEW_SIZE,
		scene_context,
		{
			"id": "mugong_negative_probe",
			"start_card_kind": "mugong",
			"unlocks_skill": "ghost_shot",
		},
		card_rects[1],
		card_rects,
		card_rects[1].get_center()
	)
	_expect(mugong_state.is_empty(), "negative leg: non-Chosik card must not open a Chosik tooltip")


func _verify_tooltip_rect(state: Dictionary, card_rects: Array[Rect2], view_size: Vector2, label: String) -> void:
	var tooltip_rect: Rect2 = state.get("tooltip_rect", Rect2())
	_expect(tooltip_rect.size.x > 0.0 and tooltip_rect.size.y > 0.0, "%s Chosik tooltip must expose a separate panel rect" % label)
	_expect(
		tooltip_rect.position.x >= 0.0
		and tooltip_rect.position.y >= 0.0
		and tooltip_rect.end.x <= view_size.x
		and tooltip_rect.end.y <= view_size.y,
		"%s Chosik tooltip must remain inside the actual viewport" % label
	)
	for card_rect in card_rects:
		_expect(not tooltip_rect.intersects(card_rect), "%s Chosik tooltip must not cover any choice card" % label)


func _verify_single_owner_wiring() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var start_begin := overlay_source.find("func draw_tower_start_card(")
	var reward_begin := overlay_source.find("func draw_tower_reward_pick(", start_begin)
	var helper_begin := overlay_source.find("func _draw_hovered_tower_chosik_tooltip(", reward_begin)
	_expect(start_begin >= 0 and reward_begin > start_begin and helper_begin > reward_begin, "tower tooltip renderer boundaries must remain discoverable")
	if start_begin >= 0 and reward_begin > start_begin:
		var start_source := overlay_source.substr(start_begin, reward_begin - start_begin)
		_expect(start_source.find("_draw_hovered_tower_chosik_tooltip(") >= 0, "start-card draw must call the shared Chosik tooltip bridge")
	if reward_begin >= 0 and helper_begin > reward_begin:
		var reward_source := overlay_source.substr(reward_begin, helper_begin - reward_begin)
		_expect(reward_source.find("_draw_hovered_tower_chosik_tooltip(") >= 0, "reward-card draw must call the shared Chosik tooltip bridge")

	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
	_expect(tooltip_source.find("SkillOrbTooltipEffectPreviewRenderer := preload") >= 0, "card tooltip must remain owned by the existing skill-orb tooltip renderer")
	_expect(tooltip_source.find("effect_preview_renderer.draw(canvas, rect, effect_type, color, _progress)") >= 0, "card tooltip must retain the existing effect-preview renderer")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
