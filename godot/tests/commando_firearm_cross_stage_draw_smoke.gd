extends SceneTree

const Stage2ActorRenderer := preload("res://scripts/stages/stage2/stage2_actor_renderer.gd")
const Stage3ActorRenderer := preload("res://scripts/stages/stage3/stage3_actor_renderer.gd")
const Stage4ActorRenderer := preload("res://scripts/stages/stage4/stage4_actor_renderer.gd")

var _failures: Array[String] = []
var _canvas := Node2D.new()


class DrawRecorder:
	extends RefCounted

	var draw_calls := 0
	var moon_fragment_calls := 0
	var last_context: Dictionary = {}
	var last_shake_offset := Vector2.ZERO

	func draw(_canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
		draw_calls += 1
		last_context = context
		last_shake_offset = shake_offset

	func draw_moon_fragments(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2) -> void:
		moon_fragment_calls += 1


func _init() -> void:
	get_root().add_child(_canvas)
	_verify_renderer("Stage 2", Stage2ActorRenderer.new(), {
		"playfield_renderer": DrawRecorder.new(),
		"player_renderer": DrawRecorder.new(),
		"boss_renderer": DrawRecorder.new(),
	})
	_verify_renderer("Stage 3", Stage3ActorRenderer.new(), {
		"playfield_renderer": DrawRecorder.new(),
		"skill_effect_renderer": DrawRecorder.new(),
		"player_renderer": DrawRecorder.new(),
		"boss_renderer": DrawRecorder.new(),
	})
	_verify_renderer("Stage 4", Stage4ActorRenderer.new(), {
		"playfield_renderer": DrawRecorder.new(),
		"monk_event_renderer": DrawRecorder.new(),
		"player_renderer": DrawRecorder.new(),
		"boss_renderer": DrawRecorder.new(),
		"ponk_skill_renderer": DrawRecorder.new(),
		"bird_event_renderer": DrawRecorder.new(),
	})
	if _failures.is_empty():
		print("commando_firearm_cross_stage_draw_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_renderer(label: String, renderer: Object, replacements: Dictionary) -> void:
	for property_name in replacements.keys():
		renderer.set(str(property_name), replacements[property_name])
	var commando_recorder := DrawRecorder.new()
	renderer.set("commando_firearm_renderer", commando_recorder)
	renderer.draw(_canvas, _build_commando_context())
	_expect(
		commando_recorder.draw_calls == 1,
		"%s actor renderer should draw Commando firearm projectiles" % label
	)
	_expect(
		commando_recorder.last_shake_offset == Vector2(3.0, -2.0),
		"%s actor renderer should pass the live shake offset to Commando firearm rendering" % label
	)
	var projectiles: Array = commando_recorder.last_context.get("commando_firearm_projectiles", [])
	_expect(
		projectiles.size() == 1 and str((projectiles[0] as Dictionary).get("weapon_id", "")) == "commando_pistol",
		"%s actor renderer should preserve the Commando pistol projectile context" % label
	)


func _build_commando_context() -> Dictionary:
	return {
		"shake_offset": Vector2(3.0, -2.0),
		"stage3_kuromi_awakening": false,
		"stage4_player_burn_active": false,
		"stage4_player_burn_ratio": 0.0,
		"commando_firearm_projectiles": [
			{
				"weapon_id": "commando_pistol",
				"kind": "bullet",
				"pos": Vector2(360.0, 420.0),
				"prev_pos": Vector2(348.0, 440.0),
			},
		],
		"commando_firearm_muzzle_flashes": [],
		"commando_firearm_impact_flashes": [],
		"commando_firearm_lingering_effects": [],
		"commando_firearm_shell_casings": [],
		"commando_firearm_pistol_feedbacks": [],
		"commando_firearm_support_calls": [],
		"commando_firearm_bowling_traps": [],
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
