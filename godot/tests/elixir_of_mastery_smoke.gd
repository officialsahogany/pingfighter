extends SceneTree
## 대성영단 스모크 테스트 (호환 ID: elixir_of_mastery)
## - 카탈로그 빌드 확인
## - 런타임 activate/update/confirm 흐름 확인
## - 적격 퍽 없을 때 실패 확인

const ElixirRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const ElixirCinematicDraw := preload("res://scripts/items/elixir_of_mastery_cinematic_draw.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PlazaGachaTransactions := preload("res://scripts/plaza/plaza_gacha_transactions.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")


class TrackingPerkIconRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_skill_id := ""
	var last_rect := Rect2()
	var last_alpha := 0.0
	var last_active := false

	func has_icon(skill_id: String) -> bool:
		return skill_id == "item_cooldown_mastery"

	func draw_icon(
		_canvas: CanvasItem,
		skill_id: String,
		rect: Rect2,
		alpha: float = 1.0,
		active: bool = true
	) -> bool:
		draw_calls += 1
		last_skill_id = skill_id
		last_rect = rect
		last_alpha = alpha
		last_active = active
		return true


class ElixirOverlayModalGate:
	extends RefCounted

	func is_elixir_cinematic_active(_module_getter: Callable) -> bool:
		return true


class TrackingElixirRuntime:
	extends RefCounted

	var draw_calls := 0
	var last_view_size := Vector2.ZERO
	var last_icon_renderer: Object = null

	func draw_elixir_cinematic(
		_canvas: CanvasItem,
		view_size: Vector2,
		perk_icon_renderer: Object = null
	) -> void:
		draw_calls += 1
		last_view_size = view_size
		last_icon_renderer = perk_icon_renderer

var _pass_count: int = 0
var _fail_count: int = 0
var _overlay_modules: Dictionary = {}


func _init() -> void:
	_run_tests()
	var exit_code: int = 1 if _fail_count > 0 else 0
	if _fail_count > 0:
		print("FAILED: %d test(s) failed" % _fail_count)
	else:
		print("ALL %d TESTS PASSED" % _pass_count)
		print("elixir_of_mastery_smoke: ok")
	quit(exit_code)


func _run_tests() -> void:
	_test_active_catalog_build()
	_test_low_probability_acquisition_routes()
	_test_mythic_catalog_build()
	_test_runtime_no_eligible_perks()
	_test_runtime_activate_success()
	_test_runtime_cinematic_flow()
	_test_cinematic_draw_instantiation()
	_test_result_icon_linkage()
	_test_overlay_forwards_result_icon_renderer()


func _test_active_catalog_build() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_assert_eq(str(item.get("name", "")), "elixir_of_mastery", "active catalog: name")
	_assert_eq(str(item.get("display_name", "")), "대성영단", "active catalog: rebranded display_name")
	_assert_eq(str(item.get("type", "")), "active", "active catalog: type")
	_assert_eq(str(item.get("rarity", "")), "mythic", "active catalog: rarity")
	_assert_true(bool(item.get("consumable", false)), "active catalog: consumable")
	_assert_true(bool(item.get("mythic_active", false)), "active catalog: mythic_active")
	_assert_true(str(item.get("description", "")).contains("극성") and not str(item.get("description", "")).contains("Lv.5"), "active catalog: Korean description uses 극성")
	_assert_eq(str(item.get("icon_path", "")), "res://assets/sprites/items/elixir_of_mastery_icon_hq_v1.png", "active catalog: HQ icon path")
	_assert_true(FileAccess.file_exists(str(item.get("icon_path", ""))), "active catalog: rebranded icon exists")
	LanguageSettings.set_test_locale_override("")


func _test_low_probability_acquisition_routes() -> void:
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_assert_true(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("elixir_of_mastery"), "acquisition: registered in ordinary field order")
	_assert_true(is_equal_approx(float(item.get("chance", 0.0)), ActiveItemCatalog.DAESEONG_YEONGDAN_SPAWN_WEIGHT), "acquisition: uses the dedicated low raw weight")
	_assert_true(float(item.get("chance", 0.0)) < float(catalog.build_item_by_name("pandora_box").get("chance", 0.0)), "acquisition: raw weight stays below Pandora Box")

	var spawn_pool := ActiveItemFieldSpawnPool.new()
	_assert_true(spawn_pool.get_field_spawn_candidate_names().has("elixir_of_mastery"), "acquisition: production field pool includes Daeseong Yeongdan")
	var scaled_entries: Array[Dictionary] = spawn_pool.build_group_scaled_spawn_weights([
		{"name": "ordinary_active_fixture", "type": "active", "chance": 1.0},
		item,
	])
	_assert_true(is_equal_approx(_find_scaled_spawn_weight(scaled_entries, "elixir_of_mastery"), 0.01), "acquisition: base field share is the 1 percent mythic lane")

	var pandora_pool: Array = PandoraLegacyPoolBuilder.new().build_active_pool()
	_assert_true(_array_has_item(pandora_pool, "elixir_of_mastery"), "acquisition: Pandora active pool includes Daeseong Yeongdan")
	var plaza_gacha := PlazaGachaTransactions.new()
	_assert_true(plaza_gacha._get_gacha_item_names().has("elixir_of_mastery"), "acquisition: plaza active gacha includes Daeseong Yeongdan")


func _test_mythic_catalog_build() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := MythicItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_assert_eq(str(item.get("name", "")), "elixir_of_mastery", "mythic catalog: name")
	_assert_eq(str(item.get("display_name", "")), "대성영단", "mythic catalog: rebranded display_name")
	_assert_eq(str(item.get("type", "")), "mythic", "mythic catalog: type")
	_assert_eq(str(item.get("rarity", "")), "mythic", "mythic catalog: rarity")
	_assert_true(bool(item.get("mythic_active", false)), "mythic catalog: mythic_active")
	_assert_eq(str(item.get("icon_path", "")), "res://assets/sprites/items/elixir_of_mastery_icon_hq_v1.png", "mythic catalog: HQ icon path")
	var roll_options: Array = catalog.get_roll_options("elixir_of_mastery")
	_assert_eq(roll_options.size(), 0, "mythic catalog: no roll options")
	LanguageSettings.set_test_locale_override("")


func _test_runtime_no_eligible_perks() -> void:
	var runtime := ElixirRuntime.new()
	# 빈 퍽 상태 - 적격 퍽 없음
	var result: bool = runtime.activate({}, [], Callable())
	_assert_true(not result, "runtime: fails with no eligible perks (empty)")

	# 모든 퍽이 이미 Lv.5
	var levels: Dictionary = {"item_luck": 5, "item_gauge_mastery": 5}
	var pools: Array = [{"item_luck": {"max_level": 5}, "item_gauge_mastery": {"max_level": 5}}]
	result = runtime.activate(levels, pools, Callable())
	_assert_true(not result, "runtime: fails when all perks already Lv.5")

	# 퍽이 있지만 레벨 0 (아직 선택 안 함)
	var levels2: Dictionary = {"item_luck": 0}
	var pools2: Array = [{"item_luck": {"max_level": 5}}]
	result = runtime.activate(levels2, pools2, Callable())
	_assert_true(not result, "runtime: fails when perk level is 0 (not owned)")


func _test_runtime_activate_success() -> void:
	var runtime := ElixirRuntime.new()
	var applied_calls: Array = []

	var levels: Dictionary = {"item_luck": 2, "item_gauge_mastery": 5, "item_caffeine": 3}
	var pools: Array = [{"item_luck": {"max_level": 5, "name": "Power"}, "item_gauge_mastery": {"max_level": 5, "name": "Speed"}, "item_caffeine": {"max_level": 5, "name": "Defense"}}]

	var apply_func: Callable = func(skill_id: String) -> void:
		applied_calls.append(skill_id)

	var result: bool = runtime.activate(levels, pools, apply_func)
	_assert_true(result, "runtime: activate succeeds with eligible perks")
	_assert_true(runtime.cinematic_active, "runtime: cinematic is active after activate")
	_assert_true(runtime.selected_perk_id != "", "runtime: selected_perk_id is set")

	# 선택된 퍽에 대해 (5 - old_level) 번 apply 호출 확인
	var expected_calls: int = runtime.target_level - runtime.old_level
	_assert_eq(applied_calls.size(), expected_calls, "runtime: apply_choice called correct times (%d)" % expected_calls)

	# 모든 호출이 같은 퍽 ID
	for call_id in applied_calls:
		_assert_eq(call_id, runtime.selected_perk_id, "runtime: all apply calls target selected perk")


func _test_runtime_cinematic_flow() -> void:
	var runtime := ElixirRuntime.new()
	var levels: Dictionary = {"item_luck": 1}
	var pools: Array = [{"item_luck": {"max_level": 5, "name": "TestPerk"}}]
	var apply_func: Callable = func(_id: String) -> void: pass

	runtime.activate(levels, pools, apply_func)
	_assert_eq(runtime.cinematic_phase, ElixirRuntime.Phase.BUILDUP, "flow: starts in BUILDUP")
	_assert_true(runtime.should_pause_game(), "flow: should_pause_game during cinematic")

	# 빌드업 진행
	runtime.update(3.1)
	_assert_eq(runtime.cinematic_phase, ElixirRuntime.Phase.REVEAL, "flow: transitions to REVEAL")

	# 리빌 진행
	runtime.update(1.6)
	_assert_eq(runtime.cinematic_phase, ElixirRuntime.Phase.CELEBRATION, "flow: transitions to CELEBRATION")
	_assert_true(runtime.waiting_for_confirm, "flow: waiting_for_confirm in CELEBRATION")

	# 확인 전 - 아직 활성
	_assert_true(runtime.cinematic_active, "flow: still active before confirm")

	# 확인 처리
	var confirmed: bool = runtime.handle_confirm()
	_assert_true(confirmed, "flow: handle_confirm returns true")
	_assert_true(not runtime.cinematic_active, "flow: cinematic ends after confirm")
	_assert_true(not runtime.should_pause_game(), "flow: game unpaused after confirm")


func _test_cinematic_draw_instantiation() -> void:
	var draw_helper := ElixirCinematicDraw.new()
	_assert_true(draw_helper != null, "draw: cinematic draw helper instantiates")

	var runtime := ElixirRuntime.new()
	var ctx: Dictionary = runtime.get_draw_context()
	_assert_true(ctx is Dictionary, "draw: get_draw_context returns Dictionary")
	_assert_true(ctx.has("active"), "draw: context has 'active' key")
	_assert_true(ctx.has("phase"), "draw: context has 'phase' key")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_assert_eq(LanguageSettings.translate_text("Lv.5 달성!"), "극성 도달!", "draw: Korean max-rank banner")
	_assert_eq(LanguageSettings.translate_text("대성영단"), "대성영단", "draw: Korean rebranded title")
	LanguageSettings.set_test_locale_override("")
	var cinematic_source := FileAccess.get_file_as_string("res://scripts/items/elixir_of_mastery_cinematic_draw.gd")
	_assert_true(cinematic_source.contains("translate_text(\"대성영단\")"), "draw: cinematic uses rebranded title")
	_assert_true(cinematic_source.contains("translate_text(\"무공의 극성을 깨웁니다...\")"), "draw: cinematic uses Mugong buildup copy")
	_assert_true(not cinematic_source.contains("MASTERY UNLOCKED"), "draw: legacy English banner removed")
	_assert_true(not cinematic_source.contains("BOTTLE_BODY_COLOR"), "draw: legacy purple bottle drawing removed")


func _test_result_icon_linkage() -> void:
	var production_renderer := RuntimePerkIconRenderer.new()
	_assert_true(
		production_renderer.has_icon("item_cooldown_mastery"),
		"draw: selected Circulation Art id resolves to its production Mugong icon"
	)
	_assert_eq(
		str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("item_cooldown_mastery", "")),
		"res://assets/sprites/perks/item_cooldown_mastery_perk_icon.png",
		"draw: Circulation Art uses the shared production icon asset"
	)

	var tracking_renderer := TrackingPerkIconRenderer.new()
	var canvas := Node2D.new()
	var icon_rect := Rect2(12.0, 24.0, 82.0, 82.0)
	var linked: bool = ElixirCinematicDraw.new()._draw_linked_perk_icon(
		canvas,
		tracking_renderer,
		"item_cooldown_mastery",
		icon_rect,
		0.75
	)
	_assert_true(linked, "draw: result icon delegates to the shared Mugong icon renderer")
	_assert_eq(tracking_renderer.draw_calls, 1, "draw: result icon delegates exactly once")
	_assert_eq(tracking_renderer.last_skill_id, "item_cooldown_mastery", "draw: result forwards selected_perk_id")
	_assert_eq(tracking_renderer.last_rect, icon_rect, "draw: result forwards its framed icon rect")
	_assert_true(is_equal_approx(tracking_renderer.last_alpha, 0.75), "draw: result forwards reveal alpha")
	_assert_true(tracking_renderer.last_active, "draw: result requests the active full-color icon")
	canvas.free()



func _test_overlay_forwards_result_icon_renderer() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var active_runtime := TrackingElixirRuntime.new()
	var perk_icon_renderer := TrackingPerkIconRenderer.new()
	_overlay_modules = {
		"battle_scene_modal_gate_controller": ElixirOverlayModalGate.new(),
		"active_item_runtime": active_runtime,
		"runtime_perk_icon_renderer": perk_icon_renderer,
	}
	var canvas := Node2D.new()
	controller.draw(
		canvas,
		null,
		null,
		Callable(self, "_get_overlay_module"),
		Vector2(760.0, 750.0)
	)
	_assert_eq(active_runtime.draw_calls, 1, "draw: production overlay invokes the Daeseong Yeongdan result once")
	_assert_eq(active_runtime.last_view_size, Vector2(760.0, 750.0), "draw: production overlay preserves the result view size")
	_assert_true(active_runtime.last_icon_renderer == perk_icon_renderer, "draw: production overlay forwards the shared Mugong icon renderer")
	canvas.free()
	_overlay_modules.clear()


func _get_overlay_module(key: String) -> Object:
	var value: Variant = _overlay_modules.get(key, null)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


func _find_scaled_spawn_weight(entries: Array[Dictionary], item_name: String) -> float:
	for entry in entries:
		var item_value: Variant = entry.get("item", {})
		if item_value is Dictionary and str((item_value as Dictionary).get("name", "")) == item_name:
			return float(entry.get("weight", 0.0))
	return 0.0


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str((item_value as Dictionary).get("name", "")) == item_name:
			return true
	return false


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s (got '%s', expected '%s')" % [label, str(actual), str(expected)])
