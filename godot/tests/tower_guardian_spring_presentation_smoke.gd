extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const GuardianCodexStore := preload(
	"res://scripts/lingpet/guardian_codex_store.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const SmasherSkillConfig := preload(
	"res://scripts/characters/smasher_skill_config.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerGuardianSpringPresentationAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_presentation_asset_catalog.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const GuardianSpringProductionFixtureTypes := preload(
	"res://tests/tower_ascent_guardian_spring_node_smoke.gd"
)

const APPROVED_ASSETS := {
	"background": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_scene_background_imagegen_v1.png",
		"size": Vector2i(760, 750),
		"sha256": "7b6a46700bccc5909dbec1674465b15ca2c6d65c42bfd5fece9e7cc822f601da",
	},
	"statue": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_statue_palm_stele_imagegen_v1.png",
		"size": Vector2i(1024, 1536),
		"sha256": "db89e6368d68e66cf7509d7a3ccbf54c72c84c764864b49a92aac12590433919",
	},
	"glow": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_statue_glow_overlay_imagegen_v1.png",
		"size": Vector2i(1024, 1536),
		"sha256": "a8610ef6c6783f1ab4eca1c15350c85056870e65456f8db803a1c2a9727c5f20",
	},
	"capsule": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_capsule_frame_jade_seed_imagegen_v1.png",
		"size": Vector2i(1086, 1448),
		"sha256": "4e61d7efb256a37e477bd52a30ec57c26a116d3818444f48227c037438ec6303",
	},
	"ritual_ring": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_ritual_jade_ring_imagegen_v1.png",
		"size": Vector2i(1024, 1024),
		"sha256": "54f7059ebaa4d205470892613aee74b9e647d824043efd7f9fb98394d51511ca",
		"source_png": true,
	},
	"ritual_backplate": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_ritual_jade_backplate_imagegen_v1.png",
		"size": Vector2i(1024, 1024),
		"sha256": "d8e0d9d360765ab35fd004322320c6c07bb45ac8b196efd21d60446d8d7e2ae1",
		"source_png": true,
	},
	"soul_seal_shard": {
		"path": "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_soul_seal_shard_imagegen_v1.png",
		"size": Vector2i(512, 512),
		"sha256": "29d39fabaaf27b4c8380faedc3e60ab9f071c1bd8020a703424cf87e874d2639",
		"source_png": true,
	},
}

var _failures: Array[String] = []
var _cold_prewarm_usec := 0
var _outside_glow_pixel_count := -1


class FakeAssetBackend:
	extends RefCounted
	var missing_key := ""
	var exists_calls := 0
	var load_calls := 0

	func exists(path: String) -> bool:
		exists_calls += 1
		return missing_key == "" or path.find(missing_key) < 0

	func load_asset(path: String) -> Texture2D:
		load_calls += 1
		var size := Vector2i.ZERO
		if path.find("scene_background") >= 0:
			size = Vector2i(760, 750)
		elif path.find("capsule_frame") >= 0:
			size = Vector2i(1086, 1448)
		elif path.find("soul_seal_shard") >= 0:
			size = Vector2i(512, 512)
		elif path.find("ritual_jade") >= 0:
			size = Vector2i(1024, 1024)
		else:
			size = Vector2i(1024, 1536)
		return ImageTexture.create_from_image(Image.create_empty(
			size.x,
			size.y,
			false,
			Image.FORMAT_RGBA8
		))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_approved_asset_contract_and_cold_prewarm()
	_verify_glow_alpha_is_bounded_by_statue_silhouette()
	_verify_missing_asset_all_or_nothing_fallback()
	_verify_statue_draw_hit_and_top_corner_counterproof()
	_verify_staged_ritual_confirmation_prayer_and_exactly_once_dispatch()
	_verify_production_flow_ritual_route()
	_verify_capsule_draw_hit_float_and_hover_policy()
	_verify_localization_and_source_ownership()
	if _failures.is_empty():
		call_deferred("_finish_after_resource_release")
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _finish_after_resource_release() -> void:
	await process_frame
	await process_frame
	print("tower_guardian_spring_presentation_smoke: APPROVED_ASSETS_HASH_SIZE_PREWARM_OK")
	print("tower_guardian_spring_presentation_smoke: GLOW_OUTSIDE_STATUE_PIXELS=%d" % _outside_glow_pixel_count)
	print("tower_guardian_spring_presentation_smoke: STATUE_DRAW_HIT_TOP_CORNER_RED_OK")
	print("tower_guardian_spring_presentation_smoke: PALM_3P4_REVEAL_CONFIRM_ABSORB_IMPACT_PRAYER_2S_OK")
	print("tower_guardian_spring_presentation_smoke: PRODUCTION_FLOW_RITUAL_TRANSACTION_OK")
	print("tower_guardian_spring_presentation_smoke: CAPSULE_FLOAT_DRAW_HIT_TOOLTIP_OK")
	print("tower_guardian_spring_presentation_smoke: MISSING_ASSET_V1_FALLBACK_OK")
	print("tower_guardian_spring_presentation_smoke: COLD_PREWARM_USEC=%d" % _cold_prewarm_usec)
	print("tower_guardian_spring_presentation_smoke: ok")
	quit(0)


func _verify_approved_asset_contract_and_cold_prewarm() -> void:
	for key_value in APPROVED_ASSETS.keys():
		var key := str(key_value)
		var spec: Dictionary = APPROVED_ASSETS[key]
		var path := str(spec.get("path", ""))
		_expect(FileAccess.file_exists(path), "%s approved source exists" % key)
		_expect(
			FileAccess.get_sha256(path).to_lower() == str(spec.get("sha256", "")),
			"%s approved source hash is pinned" % key
		)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty(), "%s approved source decodes" % key)
		if image != null and not image.is_empty():
			_expect(image.get_size() == spec.get("size", Vector2i.ZERO), "%s source size is pinned" % key)
			if bool(spec.get("source_png", false)):
				_expect(image.get_pixel(0, 0).a < 0.02, "%s keeps a transparent outer corner" % key)
			if key == "ritual_ring":
				_expect(image.get_pixel(int(image.get_width() * 0.5), int(image.get_height() * 0.5)).a < 0.05, "jade ring keeps its center transparent")
			elif key == "ritual_backplate":
				_expect(image.get_pixel(int(image.get_width() * 0.5), int(image.get_height() * 0.5)).a > 0.50, "jade backplate supplies a filled luminous center")
		if not bool(spec.get("source_png", false)):
			var import_path := path + ".import"
			var import_text := _read_text(import_path)
			_expect(not import_text.is_empty(), "%s import sidecar exists" % key)
			_expect(import_text.find("compress/mode=2") >= 0, "%s uses VRAM compression" % key)
			_expect(import_text.find("compress/high_quality=true") >= 0, "%s uses high quality VRAM compression" % key)
			_expect(import_text.find("\"vram_texture\": true") >= 0, "%s import metadata is VRAM" % key)
	var catalog := TowerGuardianSpringPresentationAssetCatalog.new()
	var bundle: Dictionary = catalog.prewarm_all()
	_cold_prewarm_usec = int(bundle.get("cold_prewarm_usec", -1))
	_expect(bool(bundle.get("ready", false)), "approved asset bundle prewarms all-or-nothing")
	_expect(_cold_prewarm_usec >= 0, "cold prewarm timing is recorded")
	var first_debug: Dictionary = catalog.get_debug_state()
	_expect(int(first_debug.get("filesystem_probe_count", 0)) == 7, "cold prewarm probes each source once")
	_expect(int(first_debug.get("resource_load_count", 0)) == 7, "cold prewarm loads each source once")
	var warm_bundle: Dictionary = catalog.prewarm_all()
	var warm_debug: Dictionary = catalog.get_debug_state()
	_expect(bool(warm_bundle.get("cache_hit", false)), "second prewarm is a cache hit")
	_expect(int(warm_bundle.get("cold_prewarm_usec", -1)) == 0, "warm bundle reports zero cold work")
	_expect(int(warm_debug.get("filesystem_probe_count", 0)) == 7, "warm read performs no filesystem probe")
	_expect(int(warm_debug.get("resource_load_count", 0)) == 7, "warm read performs no resource load")


func _verify_glow_alpha_is_bounded_by_statue_silhouette() -> void:
	var statue := Image.load_from_file(ProjectSettings.globalize_path(str(APPROVED_ASSETS.statue.path)))
	var glow := Image.load_from_file(ProjectSettings.globalize_path(str(APPROVED_ASSETS.glow.path)))
	if statue == null or statue.is_empty() or glow == null or glow.is_empty():
		_expect(false, "statue and glow decode for alpha comparison")
		return
	statue.convert(Image.FORMAT_RGBA8)
	glow.convert(Image.FORMAT_RGBA8)
	_expect(statue.get_size() == glow.get_size(), "statue and glow source grids match")
	var statue_bytes := statue.get_data()
	var glow_bytes := glow.get_data()
	var outside_count := 0
	var alpha_mismatch_count := 0
	for byte_index in range(3, mini(statue_bytes.size(), glow_bytes.size()), 4):
		var statue_alpha := int(statue_bytes[byte_index])
		var glow_alpha := int(glow_bytes[byte_index])
		if glow_alpha > 0 and statue_alpha == 0:
			outside_count += 1
		if glow_alpha != statue_alpha:
			alpha_mismatch_count += 1
	_outside_glow_pixel_count = outside_count
	_expect(outside_count == 0, "glow has zero nontransparent pixels outside the statue silhouette")
	_expect(alpha_mismatch_count == 0, "glow and statue use the exact same alpha silhouette")


func _verify_missing_asset_all_or_nothing_fallback() -> void:
	var backend := FakeAssetBackend.new()
	backend.missing_key = "glow_overlay"
	var catalog := TowerGuardianSpringPresentationAssetCatalog.new(
		Callable(backend, "exists"),
		Callable(backend, "load_asset")
	)
	var bundle: Dictionary = catalog.prewarm_all()
	_expect(not bool(bundle.get("ready", true)), "one missing approved asset rejects the rich bundle")
	_expect(bool(bundle.get("fallback_to_v1", false)), "one missing approved asset selects v1 fallback")
	_expect(backend.exists_calls == 7, "fallback fixture probes all seven declared paths once")
	_expect(backend.load_calls == 6, "fallback fixture never tries to load the missing source")
	catalog.prewarm_all()
	_expect(backend.exists_calls == 7 and backend.load_calls == 6, "fallback result is cached without frame probes")

	var actions := _menu_actions()
	var baseline := TowerAscentNodeModalState.new()
	baseline.open("spring-baseline", "guardian_spring", {"gold": 0, "muhon": 0}, actions)
	var fallback := TowerAscentNodeModalState.new()
	fallback.open("spring-fallback", "guardian_spring", {"gold": 0, "muhon": 0}, actions)
	_expect(not fallback.configure_guardian_spring_presentation(false), "missing bundle leaves rich state disabled")
	_expect(
		fallback.get_action_rects() == baseline.get_action_rects(),
		"missing bundle preserves the current v1 modal geometry exactly"
	)
	_expect(
		not bool(fallback.build_view_model().has("guardian_spring_presentation")),
		"missing bundle does not expose a partial presentation model"
	)


func _verify_statue_draw_hit_and_top_corner_counterproof() -> void:
	var modal := TowerAscentNodeModalState.new()
	modal.open("spring-statue", "guardian_spring", {"gold": 0, "muhon": 0}, _menu_actions())
	_expect(modal.configure_guardian_spring_presentation(true), "ready bundle enables statue presentation")
	var model: Dictionary = modal.build_view_model()
	var presentation: Dictionary = model.get("guardian_spring_presentation", {})
	var statue_rect: Rect2 = presentation.get("statue_rect", Rect2())
	_expect(statue_rect.has_area(), "statue draw rect exists")
	_expect(modal.get_action_rects() == presentation.get("action_rects", []), "statue phase draw and hit action rect arrays share one owner")
	var outside_top_corner := statue_rect.position - Vector2.ONE
	_expect(not modal.begin_pointer_press(outside_top_corner), "RED: one pixel beyond statue top corner cannot arm")
	_expect(modal.release_pointer_at_position(outside_top_corner).is_empty(), "RED: one pixel beyond statue top corner cannot activate")
	var inside_top_corner := statue_rect.position + Vector2.ONE
	_expect(modal.update_hover_at_position(inside_top_corner), "inside statue top corner changes hover")
	_expect(bool(modal.begin_pointer_press(inside_top_corner)), "inside statue draw rect arms hit owner")
	_expect(
		str(modal.release_pointer_at_position(inside_top_corner).get("_modal_control", "")) == "guardian_statue",
		"inside statue draw rect activates the same hit owner"
	)
	_expect(modal.reveal_guardian_spring_menu(), "statue activation reveals canonical Spring menu")
	modal.set_status_text(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_DIALOGUE])
	model = modal.build_view_model()
	presentation = model.get("guardian_spring_presentation", {})
	_expect(str(presentation.get("phase", "")) == "menu", "statue dialogue advances to menu phase")
	_expect(model.get("action_rects", []) == presentation.get("action_rects", []), "menu draw and hit rect arrays are byte-identical")


func _verify_staged_ritual_confirmation_prayer_and_exactly_once_dispatch() -> void:
	var modal := TowerAscentNodeModalState.new()
	var actions := _menu_actions()
	modal.open("spring-ritual", "guardian_spring", {"gold": 0, "muhon": 0}, actions)
	modal.configure_guardian_spring_presentation(true, Vector2(640.0, 690.0))
	modal.reveal_guardian_spring_menu()
	_expect(modal.begin_guardian_spring_ritual(actions[0]), "enabled palm starts ritual")
	var ritual_model: Dictionary = modal.build_view_model().get("guardian_spring_presentation", {})
	_expect(str(ritual_model.get("input_policy", "")) == "discard_all_no_skip", "ritual declares discard-all no-skip input")
	_expect(modal.get_action_rects() == ritual_model.get("action_rects", []), "ritual draw and hit expose the same empty rects")
	modal.advance_guardian_spring_presentation(3.39)
	var debug: Dictionary = modal.get_guardian_spring_presentation_debug_state()
	_expect(str(debug.get("phase", "")) == "ascend", "palm remains in ascent before 3.4 seconds")
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "palm cannot dispatch before confirmation")
	modal.advance_guardian_spring_presentation(0.02)
	debug = modal.get_guardian_spring_presentation_debug_state()
	_expect(str(debug.get("phase", "")) == "reveal", "palm enters 0.4-second reveal after ascent")
	modal.advance_guardian_spring_presentation(0.41)
	debug = modal.get_guardian_spring_presentation_debug_state()
	_expect(bool(debug.get("confirmation_active", false)), "palm waits indefinitely at confirmation")
	modal.advance_guardian_spring_presentation(30.0)
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "elapsed time cannot skip confirmation")
	_expect(modal.handle_guardian_spring_confirmation_input(_pressed_key(KEY_ESCAPE)), "No/ESC is owned by confirmation")
	_expect(str(modal.get_guardian_spring_presentation_debug_state().get("phase", "")) == "menu", "No returns to menu")
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "No performs no transaction")

	modal.begin_guardian_spring_ritual(actions[0])
	modal.advance_guardian_spring_presentation(3.81)
	modal.handle_guardian_spring_confirmation_input(_pressed_action("ui_right"))
	_expect(modal.handle_guardian_spring_confirmation_input(_pressed_action("ui_accept")), "Yes starts absorption")
	debug = modal.get_guardian_spring_presentation_debug_state()
	_expect(bool(debug.get("acquisition_started", false)), "absorption starts only after Yes")
	_expect(int(debug.get("acquisition_start_count", 0)) == 1, "absorption starts exactly once")
	modal.advance_guardian_spring_presentation(3.39)
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "palm waits through absorption and impact")
	modal.advance_guardian_spring_presentation(0.02)
	var completed: Dictionary = modal.take_completed_guardian_spring_action()
	_expect(str(completed.get("id", "")) == "guardian_spring:palm", "palm dispatches after impact")
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "completed ritual cannot dispatch twice")
	debug = modal.get_guardian_spring_presentation_debug_state()
	_expect(int(debug.get("action_dispatch_count", 0)) == 1, "palm transaction dispatch count is exactly one")
	_expect(int(debug.get("acquisition_start_count", 0)) == 1, "post-completion polling does not repeat absorption")

	modal.configure_guardian_spring_presentation(true)
	modal.reveal_guardian_spring_menu()
	modal.begin_guardian_spring_ritual(actions[1])
	modal.advance_guardian_spring_presentation(1.99)
	_expect(modal.take_completed_guardian_spring_action().is_empty(), "prayer does not dispatch before two seconds")
	modal.advance_guardian_spring_presentation(0.02)
	var prayer_completed: Dictionary = modal.take_completed_guardian_spring_action()
	_expect(str(prayer_completed.get("payload", {}).get("operation", "")) == "prayer", "prayer dispatches once after two seconds")

	modal.configure_guardian_spring_presentation(true)
	modal.reveal_guardian_spring_menu()
	modal.begin_guardian_spring_ritual(actions[0])
	modal.advance_guardian_spring_presentation(0.4)
	modal.close()
	debug = modal.get_guardian_spring_presentation_debug_state()
	_expect(int(debug.get("forced_cleanup_count", 0)) == 1, "closing an active ritual records forced cleanup")
	_expect(not bool(debug.get("ritual_active", true)), "closing an active ritual clears its lifecycle")


func _verify_production_flow_ritual_route() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var owner := GuardianSpringProductionFixtureTypes.FakeOwner.new()
	var runtime := GuardianSpringProductionFixtureTypes.FakeLingpetRuntime.new()
	var registry := GuardianSpringProductionFixtureTypes.FakeRegistry.new()
	var codex := GuardianCodexStore.new()
	codex.set_save_path("user://tower_guardian_spring_presentation_smoke.cfg")
	codex.clear()
	registry.instances = {
		"guardian_codex_store": codex,
		"lingpet_egg_runtime": runtime,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_state": RuntimePerkState.new(),
		"smasher_skill_config": SmasherSkillConfig.new(),
	}
	var flow := TowerAscentFlowOwner.new()
	registry.instances["tower_ascent_flow_owner"] = flow
	var map_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed("guardian_spring")
	var started := flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "guardian-spring-presentation-production",
		"map_seed": map_seed,
		"node_modal_kind": "guardian_spring",
		"run_state": {"muhon": 0, "gold": 0, "chance_gems": 3},
		"registry": registry,
	})
	_expect(bool(started), "production flow starts for presentation ritual route")
	var arrived := (
		bool(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(
			flow,
			"guardian_spring",
			owner
		))
		if started
		else false
	)
	_expect(arrived, "production flow reaches guardian-spring modal")
	if arrived:
		var debug: Dictionary = flow.get_guardian_spring_presentation_debug_state()
		_expect(str(debug.get("phase", "")) == "statue", "production entry starts at statue phase")
		flow.handle_input(_pressed_key(KEY_ENTER))
		debug = flow.get_guardian_spring_presentation_debug_state()
		var menu_model: Dictionary = flow.get_node_modal_view_model(Vector2(760.0, 750.0))
		_expect(str(debug.get("phase", "")) == "menu", "production Enter reveals Spring menu")
		_expect(
			str(menu_model.get("status_text", "")) == "바위에서 영험한 기운이 흘러나옵니다",
			"production statue route displays the exact approved dialogue"
		)
		flow.handle_input(_pressed_key(KEY_ENTER))
		debug = flow.get_guardian_spring_presentation_debug_state()
		_expect(bool(debug.get("ritual_active", false)), "production palm action starts retained ritual")
		var rng_before: Dictionary = flow.export_snapshot().get("gameplay_rng_state", {}).duplicate(true)
		flow.update_selective(3.79, owner)
		flow.handle_input(_pressed_key(KEY_ESCAPE))
		debug = flow.get_guardian_spring_presentation_debug_state()
		_expect(str(debug.get("phase", "")) == "reveal", "pre-confirmation input is discarded instead of skipping")
		_expect(
			flow.export_snapshot().get("gameplay_rng_state", {}) == rng_before,
			"production presentation leaves gameplay RNG byte-identical"
		)
		flow.update_selective(0.02, owner)
		debug = flow.get_guardian_spring_presentation_debug_state()
		_expect(bool(debug.get("confirmation_active", false)), "production palm reaches owned confirmation")
		flow.handle_guardian_spring_confirmation_input(_pressed_key(KEY_ESCAPE), Vector2(760.0, 750.0))
		_expect(not flow.has_soul_summoning(), "No performs no production transaction")
		_expect(flow.get_guardian_spring_history().is_empty(), "No records no history")
		flow.handle_input(_pressed_key(KEY_ENTER))
		flow.update_selective(3.81, owner)
		flow.handle_guardian_spring_confirmation_input(_pressed_action("ui_right"), Vector2(760.0, 750.0))
		flow.handle_guardian_spring_confirmation_input(_pressed_action("ui_accept"), Vector2(760.0, 750.0))
		flow.update_selective(3.39, owner)
		_expect(not flow.has_soul_summoning(), "production palm waits through absorption and impact")
		flow.update_selective(0.02, owner)
		_expect(flow.has_soul_summoning(), "production flow commits palm after Yes and impact")
		_expect(flow.get_guardian_spring_history().size() == 1, "production flow records palm exactly once")
		var first_pick_count := 0
		for action_value in flow.get_node_modal_view_model(Vector2(760.0, 750.0)).get("actions", []):
			if (
				action_value is Dictionary
				and str((action_value as Dictionary).get("payload", {}).get("operation", "")) == "first_pick"
			):
				first_pick_count += 1
		_expect(first_pick_count == 3, "production ritual completion exposes exactly three first-pick capsules")
		flow.update_selective(0.5, owner)
		_expect(flow.get_guardian_spring_history().size() == 1, "post-completion updates cannot repeat palm transaction")
	# The fixture registry intentionally mirrors the live owner cycle. Break it
	# explicitly so the focused smoke also seals clean presentation teardown.
	flow.call("_reset_runtime_state")
	registry.instances.clear()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	codex.clear()


func _verify_capsule_draw_hit_float_and_hover_policy() -> void:
	var actions := _capsule_actions()
	var modal := TowerAscentNodeModalState.new()
	modal.open("spring-capsules", "guardian_spring", {"gold": 9999, "muhon": 0}, actions)
	modal.configure_guardian_spring_presentation(true)
	modal.reveal_guardian_spring_menu()
	var model_a: Dictionary = modal.build_view_model()
	var presentation_a: Dictionary = model_a.get("guardian_spring_presentation", {})
	var rects_a: Array = model_a.get("action_rects", [])
	_expect(bool(presentation_a.get("capsule_mode", false)), "three guardian choices switch to capsule mode")
	_expect(rects_a == presentation_a.get("action_rects", []), "capsule frame draw rects equal hit rects")
	for index in range(3):
		var rect: Rect2 = rects_a[index]
		_expect(rect.has_area(), "capsule %d has a drawable rect" % index)
		modal.update_hover_at_position(rect.get_center())
		_expect(modal.get_hovered_index() == index, "capsule %d floating center hits its own action" % index)
	modal.advance_guardian_spring_presentation(0.91)
	var model_b: Dictionary = modal.build_view_model()
	var rects_b: Array = model_b.get("action_rects", [])
	_expect(rects_b == model_b.get("guardian_spring_presentation", {}).get("action_rects", []), "second float frame still shares draw and hit rects")
	_expect((rects_a[0] as Rect2).position.y != (rects_b[0] as Rect2).position.y, "presentation clock moves capsule frame without gameplay RNG")
	modal.update_hover_at_position((rects_b[2] as Rect2).get_center())
	_expect(modal.get_hovered_index() == 2, "moved capsule hit follows its second-frame draw rect")
	var first_choice: Dictionary = actions[0].get("payload", {}).get("choice", {})
	var browse_choice: Dictionary = actions[1].get("payload", {}).get("choice", {})
	_expect(bool(first_choice.get("guardian_blind_preview", false)), "first pick tooltip is marked blind preview")
	_expect(str(first_choice.get("description", "")).split("\n", false).size() == 1, "first pick tooltip owns exactly one description line")
	_expect(not bool(browse_choice.get("guardian_blind_preview", false)), "browse tooltip exposes full guardian details")
	_expect(str(browse_choice.get("description", "")).split("\n", false).size() == 3, "browse tooltip owns three full detail lines")
	_expect(str(actions[1].get("cost_text", "")) != "", "browse tooltip retains price copy")


func _verify_localization_and_source_ownership() -> void:
	var dialogue_key := TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_DIALOGUE
	var prompt_key := TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_PROMPT
	var confirm_key := TowerAscentNodeModalLocalization.KEY_SPRING_PALM_CONFIRM
	for locale in ["ko", "en", "zh", "ja"]:
		var locale_text: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(locale, {})
		_expect(str(locale_text.get(dialogue_key, "")) != "", "%s statue dialogue is localized" % locale)
		_expect(str(locale_text.get(prompt_key, "")) != "", "%s statue prompt is localized" % locale)
		_expect(str(locale_text.get(confirm_key, "")) != "", "%s confirmation question is localized" % locale)
	var korean_dialogue := str(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][dialogue_key])
	var korean_prompt := str(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][prompt_key])
	_expect(
		str(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][confirm_key])
		== "영혼소환술 초식을 배우시겠습니까?",
		"Korean confirmation question is exact"
	)
	_expect(korean_dialogue == "바위에서 영험한 기운이 흘러나옵니다", "Korean statue dialogue is exact")
	_expect(korean_dialogue.find("—") < 0 and korean_prompt.find("—") < 0, "new Korean copy contains no em dash")

	var renderer_source := _read_text("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
	var ritual_start := renderer_source.find("func _draw_guardian_spring_ritual(")
	var ritual_end := renderer_source.find("func _draw_guardian_spring_capsules(", ritual_start)
	var ritual_source := renderer_source.substr(ritual_start, ritual_end - ritual_start)
	_expect(ritual_start >= 0 and ritual_end > ritual_start, "ritual renderer source slice exists")
	_expect(ritual_source.find("draw_arc") < 0, "ritual retains the no procedural ring contract")
	_expect(ritual_source.find("draw_polyline") < 0, "ritual retains the no dotted/polyline ring contract")
	_expect(ritual_source.find("ritual_backplate") >= 0, "ritual consumes generated center-filled backplate")
	_expect(ritual_source.find("ritual_ring") >= 0, "ritual consumes generated jade ring")
	_expect(ritual_source.find("soul_seal_shard") >= 0, "ritual consumes generated soul-seal shards")
	_expect(ritual_source.find("for point_index in range(8)") >= 0, "ritual includes deterministic filled light points")
	_expect(ritual_source.find("draw_tower_acquisition_absorption") >= 0, "ritual reuses existing Tower Chosik absorption")
	_expect(ritual_source.find("\"trail_count\": 0") >= 0, "Guardian Spring reduces four fallback glyphs to one head glyph")
	var rich_start := renderer_source.find("func _draw_guardian_spring_presentation(")
	var rich_source := renderer_source.substr(rich_start, renderer_source.length() - rich_start)
	_expect(rich_source.find("ResourceLoader") < 0, "guardian draw path performs no resource load")
	_expect(rich_source.find("FileAccess") < 0, "guardian draw path performs no filesystem probe")
	var map_source := _read_text("res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd")
	_expect(map_source.find("prewarm_guardian_spring_presentation_assets") >= 0, "stage entry owns presentation prewarm")
	var state_source := _read_text("res://scripts/tower_ascent/tower_guardian_spring_presentation_state.gd")
	_expect(state_source.find("RandomNumberGenerator") < 0 and state_source.find("randf") < 0 and state_source.find("randi") < 0, "presentation state cannot advance gameplay RNG")
	_expect(
		str(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_COMPLETED])
		== "모든 능력치가 {bonus}%p 상승했다!",
		"Korean prayer result copy is exact"
	)


func _menu_actions() -> Array[Dictionary]:
	return [
		{
			"id": "guardian_spring:palm",
			"label": "손바닥을 대본다",
			"enabled": true,
			"payload": {"operation": "palm", "cost": 0},
		},
		{
			"id": "guardian_spring:prayer",
			"label": "기도한다",
			"enabled": true,
			"payload": {"operation": "prayer", "cost": 0},
		},
		{"id": "end_work", "label": "업무 종료", "enabled": true, "payload": {}},
	]


func _capsule_actions() -> Array[Dictionary]:
	return [
		{
			"id": "guardian_spring:first_pick:maribo",
			"label": "마리보",
			"cost_text": "무료",
			"enabled": true,
			"payload": {
				"operation": "first_pick",
				"pet_id": "maribo",
				"choice": {
					"name": "마리보",
					"description": "첫 수호령을 맞이합니다.",
					"guardian_blind_preview": true,
				},
			},
		},
		{
			"id": "guardian_spring:browse_candidate:koyora",
			"label": "코요라",
			"cost_text": "800 금화",
			"enabled": true,
			"payload": {
				"operation": "browse_candidate",
				"pet_id": "koyora",
				"choice": {
					"name": "코요라",
					"description": "능동 기술 Lv.2\n지속 기술 Lv.2\n보상 요약",
				},
			},
		},
		{
			"id": "guardian_spring:browse_candidate:rajun",
			"label": "라준",
			"cost_text": "900 금화",
			"enabled": true,
			"payload": {
				"operation": "browse_candidate",
				"pet_id": "rajun",
				"choice": {
					"name": "라준",
					"description": "능동 기술 Lv.3\n지속 기술 Lv.3\n보상 요약",
				},
			},
		},
		{"id": "end_work", "label": "업무 종료", "enabled": true, "payload": {}},
	]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _pressed_action(action_name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
