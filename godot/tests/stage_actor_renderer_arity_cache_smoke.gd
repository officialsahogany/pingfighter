extends SceneTree

const Stage2ActorRenderer := preload("res://scripts/stages/stage2/stage2_actor_renderer.gd")
const Stage3ActorRenderer := preload("res://scripts/stages/stage3/stage3_actor_renderer.gd")
const Stage4ActorRenderer := preload("res://scripts/stages/stage4/stage4_actor_renderer.gd")

var _failures: Array[String] = []


class Draw3:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2) -> void:
		pass


class Draw4:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2, _perf_logger: Object = null) -> void:
		pass


func _init() -> void:
	_verify_stage2_arity_cache()
	_verify_stage3_arity_cache()
	_verify_stage4_acceptance_cache()

	if _failures.is_empty():
		print("stage_actor_renderer_arity_cache_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage2_arity_cache() -> void:
	var renderer := Stage2ActorRenderer.new()
	var draw4 := Draw4.new()
	_expect(renderer._get_method_argument_count(draw4, "draw") >= 4, "Stage 2 actor renderer should read draw arity")
	_expect(renderer.get("_method_argument_count_cache").size() == 1, "Stage 2 actor renderer should cache the first arity lookup")
	_expect(renderer._get_method_argument_count(draw4, "draw") >= 4, "Stage 2 actor renderer should keep returning cached arity")
	_expect(renderer.get("_method_argument_count_cache").size() == 1, "Stage 2 actor renderer should reuse cached arity")


func _verify_stage3_arity_cache() -> void:
	var renderer := Stage3ActorRenderer.new()
	var draw4 := Draw4.new()
	_expect(renderer._get_method_argument_count(draw4, "draw") >= 4, "Stage 3 actor renderer should read draw arity")
	_expect(renderer.get("_method_argument_count_cache").size() == 1, "Stage 3 actor renderer should cache the first arity lookup")
	_expect(renderer._get_method_argument_count(draw4, "draw") >= 4, "Stage 3 actor renderer should keep returning cached arity")
	_expect(renderer.get("_method_argument_count_cache").size() == 1, "Stage 3 actor renderer should reuse cached arity")


func _verify_stage4_acceptance_cache() -> void:
	var renderer := Stage4ActorRenderer.new()
	var draw3 := Draw3.new()
	var draw4 := Draw4.new()
	_expect(not renderer._method_accepts_argument_count(draw3, "draw", 4), "Stage 4 actor renderer should reject 3-argument draw methods")
	_expect(renderer.get("_method_acceptance_cache").size() == 1, "Stage 4 actor renderer should cache rejected draw arity")
	_expect(renderer._method_accepts_argument_count(draw4, "draw", 4), "Stage 4 actor renderer should accept 4-argument draw methods")
	_expect(renderer.get("_method_acceptance_cache").size() == 2, "Stage 4 actor renderer should cache accepted draw arity by renderer instance")
	_expect(renderer._method_accepts_argument_count(draw4, "draw", 4), "Stage 4 actor renderer should reuse accepted draw arity")
	_expect(renderer.get("_method_acceptance_cache").size() == 2, "Stage 4 actor renderer should not grow the cache on repeated lookup")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
