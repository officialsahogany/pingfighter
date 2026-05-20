extends SceneTree
## 엘릭서 오브 마스터리 스모크 테스트
## - 카탈로그 빌드 확인
## - 런타임 activate/update/confirm 흐름 확인
## - 적격 퍽 없을 때 실패 확인

const ElixirRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const ElixirCinematicDraw := preload("res://scripts/items/elixir_of_mastery_cinematic_draw.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	_run_tests()
	var exit_code: int = 1 if _fail_count > 0 else 0
	if _fail_count > 0:
		print("FAILED: %d test(s) failed" % _fail_count)
	else:
		print("ALL %d TESTS PASSED" % _pass_count)
	quit(exit_code)


func _run_tests() -> void:
	_test_active_catalog_build()
	_test_mythic_catalog_build()
	_test_runtime_no_eligible_perks()
	_test_runtime_activate_success()
	_test_runtime_cinematic_flow()
	_test_cinematic_draw_instantiation()


func _test_active_catalog_build() -> void:
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_assert_eq(str(item.get("name", "")), "elixir_of_mastery", "active catalog: name")
	_assert_eq(str(item.get("display_name", "")), "엘릭서 오브 마스터리", "active catalog: display_name")
	_assert_eq(str(item.get("type", "")), "active", "active catalog: type")
	_assert_eq(str(item.get("rarity", "")), "mythic", "active catalog: rarity")
	_assert_true(bool(item.get("consumable", false)), "active catalog: consumable")
	_assert_true(bool(item.get("mythic_active", false)), "active catalog: mythic_active")


func _test_mythic_catalog_build() -> void:
	var catalog := MythicItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("elixir_of_mastery")
	_assert_eq(str(item.get("name", "")), "elixir_of_mastery", "mythic catalog: name")
	_assert_eq(str(item.get("type", "")), "mythic", "mythic catalog: type")
	_assert_eq(str(item.get("rarity", "")), "mythic", "mythic catalog: rarity")
	_assert_true(bool(item.get("mythic_active", false)), "mythic catalog: mythic_active")
	var roll_options: Array = catalog.get_roll_options("elixir_of_mastery")
	_assert_eq(roll_options.size(), 0, "mythic catalog: no roll options")


func _test_runtime_no_eligible_perks() -> void:
	var runtime := ElixirRuntime.new()
	# 빈 퍽 상태 - 적격 퍽 없음
	var result: bool = runtime.activate({}, [], Callable())
	_assert_true(not result, "runtime: fails with no eligible perks (empty)")

	# 모든 퍽이 이미 Lv.5
	var levels: Dictionary = {"perk_a": 5, "perk_b": 5}
	var pools: Array = [{"perk_a": {"max_level": 5}, "perk_b": {"max_level": 5}}]
	result = runtime.activate(levels, pools, Callable())
	_assert_true(not result, "runtime: fails when all perks already Lv.5")

	# 퍽이 있지만 레벨 0 (아직 선택 안 함)
	var levels2: Dictionary = {"perk_a": 0}
	var pools2: Array = [{"perk_a": {"max_level": 5}}]
	result = runtime.activate(levels2, pools2, Callable())
	_assert_true(not result, "runtime: fails when perk level is 0 (not owned)")


func _test_runtime_activate_success() -> void:
	var runtime := ElixirRuntime.new()
	var applied_calls: Array = []

	var levels: Dictionary = {"perk_a": 2, "perk_b": 5, "perk_c": 3}
	var pools: Array = [{"perk_a": {"max_level": 5, "name": "Power"}, "perk_b": {"max_level": 5, "name": "Speed"}, "perk_c": {"max_level": 5, "name": "Defense"}}]

	var apply_func: Callable = func(skill_id: String) -> void:
		applied_calls.append(skill_id)

	var result: bool = runtime.activate(levels, pools, apply_func)
	_assert_true(result, "runtime: activate succeeds with eligible perks")
	_assert_true(runtime.cinematic_active, "runtime: cinematic is active after activate")
	_assert_true(runtime.selected_perk_id != "", "runtime: selected_perk_id is set")

	# 선택된 퍽에 대해 (5 - old_level) 번 apply 호출 확인
	var expected_calls: int = 5 - runtime.old_level
	_assert_eq(applied_calls.size(), expected_calls, "runtime: apply_choice called correct times (%d)" % expected_calls)

	# 모든 호출이 같은 퍽 ID
	for call_id in applied_calls:
		_assert_eq(call_id, runtime.selected_perk_id, "runtime: all apply calls target selected perk")


func _test_runtime_cinematic_flow() -> void:
	var runtime := ElixirRuntime.new()
	var levels: Dictionary = {"perk_x": 1}
	var pools: Array = [{"perk_x": {"max_level": 5, "name": "TestPerk"}}]
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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL: %s (got '%s', expected '%s')" % [label, str(actual), str(expected)])
