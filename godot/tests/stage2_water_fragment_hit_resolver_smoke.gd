extends SceneTree

const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2WaterFragmentHitPayloadFactory := preload("res://scripts/stages/stage2/stage2_water_fragment_hit_payload_factory.gd")
const Stage2WaterFragmentHitResolver := preload("res://scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")

var _failures: Array[String] = []


class FakeAudio:
	var rockhit_calls := 0

	func play_stage2_rockhit() -> void:
		rockhit_calls += 1


func _init() -> void:
	_verify_payload_factory()
	_verify_resolver_cools_down_splash()
	_verify_resolver_returns_hits()
	_verify_background_delegates_fragment_hit_resolution()

	if _failures.is_empty():
		print("stage2_water_fragment_hit_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_payload_factory() -> void:
	var splash := {"can_hit_player": true}
	var hit: Dictionary = Stage2WaterFragmentHitPayloadFactory.build_hit(3, splash, Vector2(20.0, 30.0), Rect2(Vector2.ONE, Vector2(4.0, 5.0)))
	_expect(int(hit.get("index", -1)) == 3, "fragment hit payload should preserve index")
	_expect(hit.get("splash", {}) == splash, "fragment hit payload should preserve splash dictionary")
	_expect(hit.get("pos", Vector2.ZERO) == Vector2(20.0, 30.0), "fragment hit payload should preserve position")
	_expect((hit.get("hit_rect", Rect2()) as Rect2).size == Vector2(4.0, 5.0), "fragment hit payload should preserve hit rect")


func _verify_resolver_cools_down_splash() -> void:
	var splashes := [{
		"can_hit_player": true,
		"hit_cooldown": 2.0,
		"pos": Vector2(20.0, 20.0),
		"radius": 8.0,
	}]
	var hits: Array = Stage2WaterFragmentHitResolver.resolve_hits(
		splashes,
		[Rect2(Vector2.ZERO, Vector2(60.0, 60.0))],
		Stage2CollisionGeometry.new()
	)
	_expect(hits.is_empty(), "water fragment resolver should not hit during cooldown")
	_expect(is_equal_approx(float((splashes[0] as Dictionary).get("hit_cooldown", 0.0)), 1.0), "water fragment resolver should decrement cooldown")


func _verify_resolver_returns_hits() -> void:
	var splashes := [{
		"can_hit_player": true,
		"pos": Vector2(20.0, 20.0),
		"radius": 8.0,
		"vel": Vector2(10.0, 0.0),
	}]
	var hits: Array = Stage2WaterFragmentHitResolver.resolve_hits(
		splashes,
		[Rect2(Vector2.ZERO, Vector2(60.0, 60.0))],
		Stage2CollisionGeometry.new()
	)
	_expect(hits.size() == 1, "water fragment resolver should return overlapping splash hits")
	var hit: Dictionary = hits[0]
	_expect(int(hit.get("index", -1)) == 0, "water fragment resolver should preserve splash index")
	_expect(hit.get("pos", Vector2.ZERO) == Vector2(20.0, 20.0), "water fragment resolver should preserve hit position")
	_expect((hit.get("hit_rect", Rect2()) as Rect2).size == Vector2(60.0, 60.0), "water fragment resolver should preserve hit rect")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_water_fragment_hit_resolver.gd")
	_expect(resolver_source.find("Stage2WaterFragmentHitPayloadFactory.build_hit") >= 0, "water fragment resolver should delegate hit payload construction")
	_expect(resolver_source.find("hits.append({") < 0, "water fragment resolver should not inline hit dictionaries")
	var stage_modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(stage_modules.has("stage2_water_fragment_hit_resolver"), "stage module catalog should list water fragment hit resolver")
	_expect(stage_modules.has("stage2_water_fragment_hit_payload_factory"), "stage module catalog should list water fragment hit payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("stage2_water_fragment_hit_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/stages/stage2/stage2_water_fragment_hit_payload_factory.gd", "top-level catalog should resolve water fragment hit payload factory")


func _verify_background_delegates_fragment_hit_resolution() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2WaterFragmentHitResolver.resolve_hits") >= 0,
		"Stage 2 background source should delegate water-fragment hit resolution"
	)
	var background := Stage2PillarBackground.new()
	background.water_splashes = [{
		"can_hit_player": true,
		"pos": Vector2(20.0, 20.0),
		"radius": 8.0,
		"vel": Vector2(10.0, 0.0),
	}]
	var audio := FakeAudio.new()
	background._resolve_water_fragment_player_hits({
		"current_stage": 2,
		"player_pos": Vector2.ZERO,
		"player_paddle_size": Vector2(60.0, 60.0),
	}, {
		"audio": audio,
	})
	var splash: Dictionary = background.water_splashes[0]
	_expect(not bool(splash.get("can_hit_player", true)), "Stage 2 background should mark water fragment as handled")
	_expect(is_equal_approx(float(splash.get("hit_cooldown", 0.0)), 30.0), "Stage 2 background should keep hit cooldown side effect")
	_expect(audio.rockhit_calls == 1, "Stage 2 background should still play fragment-hit audio")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
