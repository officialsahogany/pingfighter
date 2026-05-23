extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const PreviewRenderer := preload("res://scripts/hud/skill_orb_tooltip_effect_preview_renderer.gd")

const VIEW_SIZE := Vector2i(360, 500)
const PREVIEW_COLOR := Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0)

var _failures: Array[String] = []
var _probe: CommandoSkillTooltipPreviewProbe = null
var _frame_count := 0


class CommandoSkillTooltipPreviewProbe:
	extends Node2D

	var renderer: Object = PreviewRenderer.new()
	var effect_types: Array = []
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.015, 0.018, 0.025, 1.0), true)
		for idx in range(effect_types.size()):
			var effect_type: String = str(effect_types[idx])
			var preview_rect := Rect2(Vector2(20.0, 14.0 + float(idx) * 52.0), Vector2(320.0, 46.0))
			renderer.draw(self, preview_rect, effect_type, PREVIEW_COLOR, 0.5)


func _init() -> void:
	get_root().size = VIEW_SIZE
	_probe = CommandoSkillTooltipPreviewProbe.new()
	_probe.name = "CommandoSkillTooltipPreviewProbe"
	_probe.effect_types = _collect_commando_effect_types()
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_expect(_probe != null and _probe.draw_count > 0, "Commando skill tooltip previews should render inside a live draw callback")
	_expect(_probe != null and _probe.effect_types.size() >= 2, "Commando preview smoke should cover fixed skill effects")
	if _failures.is_empty():
		print("commando_skill_tooltip_preview_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _collect_commando_effect_types() -> Array:
	var renderer: Object = PreviewRenderer.new()
	var config: Object = CommandoSkillConfig.new()
	var snapshot: Dictionary = config.get_snapshot()
	var skill_data_map: Dictionary = snapshot.get("skill_data", {}) as Dictionary
	var result: Array = []
	var seen := {}
	for skill_name in skill_data_map.keys():
		var skill_data: Dictionary = skill_data_map[skill_name]
		var effect_type: String = str(skill_data.get("effect_type", ""))
		if effect_type == "" or seen.has(effect_type):
			continue
		seen[effect_type] = true
		_expect(
			renderer.get_effect_preview_family(effect_type) == "commando",
			"Commando tooltip effect %s should not fall back to the Smasher preview" % effect_type
		)
		result.append(effect_type)
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
