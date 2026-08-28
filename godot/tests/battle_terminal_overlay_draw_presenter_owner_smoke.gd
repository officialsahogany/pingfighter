extends SceneTree

const BattleTerminalOverlayDrawPresenter := preload(
	"res://scripts/core/battle_terminal_overlay_draw_presenter.gd"
)

var _failures: Array[String] = []


class FakeScreen:
	extends RefCounted

	var route_name := ""
	var active := false
	var draw_calls := 0
	var events: Array[String] = []
	var last_owner: Object = null
	var last_registry: Object = null
	var last_view_size := Vector2.ZERO

	func _init(name: String, event_log: Array[String]) -> void:
		route_name = name
		events = event_log

	func is_active() -> bool:
		return active

	func draw(
		_canvas: CanvasItem,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> void:
		draw_calls += 1
		events.append(route_name)
		last_owner = owner
		last_registry = registry
		last_view_size = view_size


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}
	var reads: Array[String] = []

	func get_module(key: String) -> Variant:
		reads.append(key)
		return modules.get(key, null)


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_result_draw_contract()
	_verify_defeat_draw_priority()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_terminal_overlay_draw_presenter_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_result_draw_contract() -> void:
	var events: Array[String] = []
	var result := FakeScreen.new("result", events)
	result.active = true
	var continue_screen := FakeScreen.new("continue", events)
	continue_screen.active = true
	var settlement := FakeScreen.new("settlement", events)
	settlement.active = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"stage_clear_result_screen": result,
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
	}
	var canvas := Node2D.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	var drawn := bool(BattleTerminalOverlayDrawPresenter.new().draw_result_if_active(
		canvas,
		owner,
		registry,
		Callable(holder, "get_module"),
		view_size,
		perf_logger
	))
	_expect(drawn, "active result screen must claim the result draw pass")
	_expect(events == ["result"], "result draw API must not draw defeat screens")
	_expect(result.last_owner == owner and result.last_registry == registry, "result draw context must preserve owner and registry")
	_expect(result.last_view_size == view_size, "result draw must receive the live view size")
	_expect(perf_logger.labels.has("draw.frame.result_screen"), "result draw must keep its BattlePerf label")
	canvas.free()


func _verify_defeat_draw_priority() -> void:
	var events: Array[String] = []
	var continue_screen := FakeScreen.new("continue", events)
	continue_screen.active = true
	var settlement := FakeScreen.new("settlement", events)
	settlement.active = true
	var holder := ModuleHolder.new()
	holder.modules = {
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
	}
	var canvas := Node2D.new()
	var perf_logger := FakePerfLogger.new()
	var presenter: Object = BattleTerminalOverlayDrawPresenter.new()

	_expect(
		bool(presenter.draw_defeat_if_active(
			canvas,
			RefCounted.new(),
			RefCounted.new(),
			Callable(holder, "get_module"),
			Vector2(1280.0, 720.0),
			perf_logger
		)),
		"active continue screen must claim the defeat draw pass"
	)
	_expect(events == ["continue"], "continue screen must draw before and suppress settlement")
	_expect(not holder.reads.has("defeat_settlement_screen"), "continue priority must avoid settlement lookup")
	_expect(perf_logger.labels.has("draw.frame.defeat_chance_gems_continue"), "continue draw must keep its BattlePerf label")

	continue_screen.active = false
	_expect(
		bool(presenter.draw_defeat_if_active(
			canvas,
			RefCounted.new(),
			RefCounted.new(),
			Callable(holder, "get_module"),
			Vector2(1280.0, 720.0),
			perf_logger
		)),
		"settlement must draw when continue is inactive"
	)
	_expect(events == ["continue", "settlement"], "settlement must be the defeat fallback")
	_expect(perf_logger.labels.has("draw.frame.defeat_settlement"), "settlement draw must keep its BattlePerf label")
	canvas.free()


func _verify_source_ownership() -> void:
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_terminal_overlay_draw_presenter.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(presenter_source.contains("func draw_result_if_active"), "presenter must expose the early result pass")
	_expect(presenter_source.contains("func draw_defeat_if_active"), "presenter must expose the late defeat pass")
	_expect(frame_source.contains("BattleTerminalOverlayDrawPresenter.new()"), "frame controller must compose the terminal draw presenter")
	_expect(frame_source.contains("TERMINAL_OVERLAY_DRAW_CONTRACT"), "frame controller must retain dirty-smoke draw labels")
	_expect(frame_source.contains("_terminal_overlay_draw_presenter.draw_result_if_active"), "frame controller must keep result placement")
	_expect(frame_source.contains("_terminal_overlay_draw_presenter.draw_defeat_if_active"), "frame controller must keep defeat placement")
	_expect(not frame_source.contains("defeat_settlement_screen.draw"), "frame controller must not retain settlement dispatch")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
