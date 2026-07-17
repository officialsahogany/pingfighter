extends SceneTree

const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultScrollContentDrawHelper := preload("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
const StageClearResultScrollSceneHandler := preload("res://scripts/ui/stage_clear_result_scroll_scene_handler.gd")


class FakeResultScene:
	extends Control

	var stage_reward_snapshot: Dictionary = {}
	var _boxes: Array = []
	var _runtime_perk_icon_renderer: Object
	var _perk_icon_renderer: Object


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fusion_draw_id := PerkFusionIconKey.build(
		"fusion_0",
		1,
		["common_bulk_up", "common_swiftness"]
	)
	var stage_snapshot := {
		"perks": [{
			"type": "fusion",
			"draw_id": fusion_draw_id,
			"label": "fusion fixture",
		}],
		"active_items": [{"type": "active", "id": "fixture_active"}],
	}
	var icon_size := StageClearResultScrollContentDrawHelper.get_fusion_reward_card_icon_size(
		Vector2(1920.0, 1080.0),
		1.0,
		stage_snapshot,
		[]
	)
	var fitted_scale := icon_size.x / 64.0
	_expect(icon_size.is_equal_approx(Vector2(64.0, 54.0) * fitted_scale), "prepared size must keep the exact reward-card icon aspect")
	# v3(재리뷰 P2): 융합 상세 패널은 이 슬라이스에 렌더러가 없다 — 실재하지
	# 않는 예약으로 fitter를 왜곡하면 안 된다. 같은 밴드 구성에서 융합 유무가
	# 카드 fitted 크기를 갈라놓지 않아야 한다(가공 규격 금지).
	var plain_snapshot := {
		"perks": [{
			"type": "perk",
			"draw_id": "common_swiftness",
			"label": "plain fixture",
		}],
		"active_items": [{"type": "active", "id": "fixture_active"}],
	}
	var plain_size := StageClearResultScrollContentDrawHelper.get_fusion_reward_card_icon_size(
		Vector2(1920.0, 1080.0),
		1.0,
		plain_snapshot,
		[]
	)
	_expect(icon_size.is_equal_approx(plain_size), "fusion rewards must not reserve phantom detail-panel space in the real card fitter")
	var content_source := FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scroll_content_draw_helper.gd")
	_expect(not content_source.contains("FUSION_DETAIL_PANEL_RESERVE"), "the phantom fusion detail panel reserve must stay removed until the panel renderer lands")

	var scene := FakeResultScene.new()
	var renderer := RuntimePerkIconRenderer.new()
	var registry_decoy_renderer := RuntimePerkIconRenderer.new()
	scene.size = Vector2(1920.0, 1080.0)
	scene.stage_reward_snapshot = stage_snapshot
	# 인스턴스 정합(v1 반려 P2): 보상 카드 드로우 컨텍스트가 소비하는 씬 로컬
	# _perk_icon_renderer가 프리웜 대상이어야 한다 — 레지스트리 주입본만
	# 데우면 카드 경로는 빈 캐시를 본다.
	scene._perk_icon_renderer = renderer
	scene._runtime_perk_icon_renderer = registry_decoy_renderer
	root.add_child(scene)
	_expect(StageClearResultScrollSceneHandler.prepare_fusion_reward_icons(scene) == 1, "result scene production handler should prepare the fusion reward icon")
	var first_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(first_stats.get("compositions", 0)) == 1, "first production preparation should compose exactly one fitted texture")
	_expect(int(registry_decoy_renderer.get_fusion_pair_cache_stats().get("compositions", 0)) == 0, "preparation must target the card-consumed scene-local renderer, not the registry-injected instance")
	_expect(renderer.prepare_fusion_pair_icon(fusion_draw_id, icon_size, true), "the exact draw-rect key should already be preparable")
	var hit_stats: Dictionary = renderer.get_fusion_pair_cache_stats()
	_expect(int(hit_stats.get("compositions", 0)) == 1, "the actual fitted draw-rect key must hit the prepared texture instead of recomposing or falling back")
	_expect(int(hit_stats.get("hits", 0)) > int(first_stats.get("hits", 0)), "the fitted key lookup should register a cache hit")

	# Result-box choices append resolved perks under box.reward, after the scene's
	# initial configure pass. That event must immediately prepare the new fusion
	# at the same fitted size rather than relying on the stale base-size prewarm.
	var late_renderer := RuntimePerkIconRenderer.new()
	scene._perk_icon_renderer = late_renderer
	scene._runtime_perk_icon_renderer = RuntimePerkIconRenderer.new()
	scene.stage_reward_snapshot = {
		"active_items": [{"type": "active", "id": "fixture_active"}],
	}
	scene._boxes = [{"reward": {"type": "starpoint", "amount": 1}}]
	StageClearResultBoxSceneHandler.append_box_resolved_perk_reward(
		scene,
		0,
		{
			"type": "fusion",
			"draw_id": fusion_draw_id,
			"label": "late fusion fixture",
		}
	)
	var late_stats := late_renderer.get_fusion_pair_cache_stats()
	_expect(int(late_stats.get("compositions", 0)) == 1, "a late result-box fusion should prepare immediately on the append production path")
	var late_reward: Dictionary = (scene._boxes[0] as Dictionary).get("reward", {}) as Dictionary
	_expect((late_reward.get("resolved_perk_rewards", []) as Array).size() == 1, "late fusion fixture should use the real nested result-box reward shape")

	# 실 진입점(v1 반려 P2): 씬 구성(configure)이 프리컴포즈를 직접 호출해야
	# 한다(드로우 핫패스 밖 준비 시점).
	var config_source := FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var configure_body := _extract_static_function_body(config_source, "static func configure(")
	_expect(configure_body.contains("prepare_fusion_reward_icons(scene)"), "scene configure must invoke the fusion reward icon precompose in production")

	scene.queue_free()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("perk_fusion_result_icon_prepare_smoke: ok")
		quit(0)
		return
	quit(1)


# 누적식 판정: quit(1) 즉시 호출은 이후 코드의 quit(0)에 덮여 RED가 exit 0
# 으로 뒤집힌다(quit은 큐잉일 뿐 실행을 멈추지 않음) — 씰 공허 방지.
var _failures: Array[String] = []


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("perk_fusion_result_icon_prepare_smoke FAIL: " + message)


# 소스씰용 static 함수 본문 추출(다음 최상위 static func 선언 전까지).
func _extract_static_function_body(source: String, function_signature_prefix: String) -> String:
	var start: int = source.find(function_signature_prefix)
	if start < 0:
		return ""
	var end: int = source.find("\nstatic func ", start + function_signature_prefix.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)
