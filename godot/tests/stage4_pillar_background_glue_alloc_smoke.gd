extends SceneTree

# Seals the Stage 4 background per-frame allocation slimming (#1a shallow context copy,
# #1b merge-cached-deps once in resolve_ball_collision). Behavior-preserving refactor:
# the #1b audio assert is the discriminating case: audio lives ONLY in last_stage4_deps,
# so it reaches the sub-resolver ONLY if resolve_ball_collision merged it before forwarding.
# Reverse-verified: replacing `_merge_cached_deps(deps)` with `deps` in resolve_ball_collision
# drops audio.birdkill_count to 0 and the smoke fails.

const Stage4PillarBackground := preload("res://scripts/stages/stage4/stage4_pillar_background.gd")

var _failures: Array[String] = []


class FakeAudio extends RefCounted:
	var birdkill_count := 0
	func play_stage4_birdkill() -> void:
		birdkill_count += 1


class FakeBird extends RefCounted:
	var crow_pos := Vector2(380.0, 120.0)
	var catch_count := 0
	func get_crow_positions() -> Array:
		return [{"x": crow_pos.x, "y": crow_pos.y, "radius": 25.0, "index": 0}]
	func catch_crow(_index: int, _deps: Dictionary, _context: Dictionary) -> bool:
		catch_count += 1
		return true


func _init() -> void:
	_verify_shallow_context_preserves_scalar_reads()
	_verify_resolve_ball_collision_forwards_merged_deps()
	_verify_structural_seals()

	if _failures.is_empty():
		print("stage4_pillar_background_glue_alloc_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# #1a: a shallow per-frame copy of the context must still surface the top-level scalar
# reads the background relies on across callbacks (here: cached brazier_lit fallback).
func _verify_shallow_context_preserves_scalar_reads() -> void:
	var bg := Stage4PillarBackground.new()
	var context := {
		"current_stage": 4,
		"stage4_brazier_lit": true,
		"nested_payload": [1, 2, 3],  # a nested value must not break the shallow copy
	}
	bg.update(0.016, context, {})
	_expect(bg.is_brazier_lit() == true, "#1a: cached brazier_lit scalar should survive a shallow context copy")


# #1b: resolve_ball_collision must merge last_stage4_deps + call deps ONCE and forward the
# merged dict to every sub-resolver. The bird arrives via the call deps; the audio arrives
# only via last_stage4_deps (primed by update). Both must be visible to the sub-resolver.
func _verify_resolve_ball_collision_forwards_merged_deps() -> void:
	var bg := Stage4PillarBackground.new()
	var audio := FakeAudio.new()
	bg.update(0.016, {"current_stage": 4}, {"audio": audio})  # prime last_stage4_deps (audio only)
	var bird := FakeBird.new()
	var scene := {"ball_pos": bird.crow_pos, "ball_size": 28.6}
	var handled: bool = bg.resolve_ball_collision(scene, {"current_stage": 4}, {"stage4_bird_event": bird})
	_expect(handled, "#1b: bird collision (passed via call deps) should resolve")
	_expect(bool(scene.get("stage4_star_bird_caught", false)), "#1b: scene should record the star-bird catch")
	_expect(bird.catch_count == 1, "#1b: fake bird catch_crow should fire exactly once")
	_expect(audio.birdkill_count == 1, "#1b: last_stage4_deps audio must reach the sub-resolver via merged deps (0 if merge dropped)")


func _verify_structural_seals() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_pillar_background.gd")
	_expect(source.find("context.duplicate(true)") < 0, "#1a seal: context must not be deep-copied per frame")
	_expect(source.find("last_stage4_context = context.duplicate()") >= 0, "#1a seal: context should use a shallow per-frame copy")
	_expect(source.find("var resolved_deps: Dictionary = _merge_cached_deps(deps)") >= 0, "#1b seal: a single merged-deps build should remain")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
