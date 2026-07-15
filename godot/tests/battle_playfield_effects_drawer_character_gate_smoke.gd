extends SceneTree

const BattlePlayfieldEffectsDrawer := preload("res://scripts/core/battle_playfield_effects_drawer.gd")
const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const Stage7AkamuActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_actor_renderer.gd")

var _failures: Array[String] = []


class RecordingRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return null


class SweepRegistry:
	extends RefCounted

	var router: RefCounted = StageRuntimeRouter.new()
	var renderers: Dictionary = {}
	var requested_keys: Array[String] = []

	func get_cached_instance(key: String) -> Object:
		requested_keys.append(key)
		if key == "stage_runtime_router":
			return router
		return renderers.get(key, null)


class SweepRenderer:
	extends RefCounted

	var clear_count := 0

	func clear_transient_canvas_items() -> void:
		clear_count += 1


class Draw2:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary) -> void:
		pass


class Draw3:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _perf_logger: Object = null) -> void:
		pass


func _init() -> void:
	var drawer: Object = BattlePlayfieldEffectsDrawer.new()
	var registry := RecordingRegistry.new()
	var viper_context := {"selected_character_type": "viper"}
	var smasher_context := {"selected_character_type": "smasher"}

	drawer.draw_power_smash_effects(null, registry, RefCounted.new(), Vector2.ZERO, viper_context)
	drawer.draw_magnum_grip_effects(null, registry, viper_context, Vector2.ZERO)
	drawer.draw_dash_spirit_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_shield_kiting_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_plasma_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_recovery_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_cleanse_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_warp_gate_effects(null, registry, Vector2.ZERO, viper_context)
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(not _has_any_requested(registry, [
		"smasher_skill_feedback_renderer",
		"smasher_magnum_grip_state",
		"smasher_dash_spirit_state",
		"smasher_shield_kiting_state",
		"smasher_plasma_state",
		"smasher_recovery_state",
		"smasher_cleanse_state",
		"smasher_warp_gate_state",
		"smasher_wheel_state",
	]), "non-Smasher context should skip Smasher-only playfield effect lookups")

	registry.requested_keys.clear()
	drawer.draw_viper_skill_effects(null, registry, Vector2.ZERO, smasher_context)
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "Smasher context should skip Viper skill effect lookup")

	registry.requested_keys.clear()
	drawer.draw_commando_supply_drop_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(not registry.requested_keys.has("commando_supply_drop_state"), "Viper context should skip Commando supply-drop lookup")

	registry.requested_keys.clear()
	drawer.draw_viper_skill_effects(null, registry, Vector2.ZERO, viper_context)
	_expect(registry.requested_keys.has("viper_skill_runtime"), "Viper context should still request Viper skill runtime")

	registry.requested_keys.clear()
	drawer.draw_commando_supply_drop_effects(null, registry, Vector2.ZERO, {"selected_character_type": "commando"})
	_expect(registry.requested_keys.has("commando_supply_drop_state"), "Commando alias should still request supply-drop state")

	registry.requested_keys.clear()
	drawer.draw_blacksmith_thor_shield_effects(null, registry, Vector2.ZERO, {"selected_character_type": " Kohaku "})
	_expect(registry.requested_keys.has("blacksmith_thor_shield_state"), "Kohaku alias should still request Blacksmith shield state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, smasher_context)
	_expect(registry.requested_keys.has("smasher_wheel_state"), "Smasher context should still request Smasher wheel state")

	# 비활성 스테이지 액터 transient 스위프가 stage7(아카무)을 포함해 라우팅되는
	# 전 스테이지를 순회하는지 행동 씰(수정: WIP 파괴로 7이 스위프에서 빠졌던 회귀).
	# 라우터 fallback이 씰을 공허화하지 못하도록 stage7 키를 정확 비교하고,
	# 1~7 키 전원 고유 + 스위프가 방문한 집합이 정확히 {2..7}(8 없음)임을 본다.
	var sweep_registry := SweepRegistry.new()
	var sweep_keys: Dictionary = {}
	var sweep_targets: Dictionary = {}
	for sweep_stage in [1, 2, 3, 4, 5, 6, 7]:
		var sweep_key: String = str(sweep_registry.router.get_module_key(sweep_stage, "actor_renderer"))
		_expect(sweep_key != "", "stage runtime router should route an actor renderer for stage %d" % sweep_stage)
		_expect(not sweep_keys.has(sweep_key), "stage %d actor renderer key must be unique (got duplicate '%s')" % [sweep_stage, sweep_key])
		sweep_keys[sweep_key] = sweep_stage
		var sweep_renderer := SweepRenderer.new()
		sweep_registry.renderers[sweep_key] = sweep_renderer
		sweep_targets[sweep_stage] = sweep_renderer
	_expect(
		str(sweep_registry.router.get_module_key(7, "actor_renderer")) == "stage7_akamu_actor_renderer",
		"stage 7 must route to the Akamu actor renderer key exactly (a stage-1 fallback would void this sweep seal)"
	)
	drawer._clear_inactive_stage_actor_transients(sweep_registry, 1, null)
	var cleared_stages: Array = []
	for sweep_stage in sweep_targets:
		if int((sweep_targets[sweep_stage] as Object).get("clear_count")) > 0:
			cleared_stages.append(int(sweep_stage))
	cleared_stages.sort()
	_expect(cleared_stages == [2, 3, 4, 5, 6, 7], "inactive-stage transient sweep must visit exactly stages 2..7 (got %s)" % [cleared_stages])
	for sweep_stage in sweep_targets:
		var expected: int = 0 if int(sweep_stage) == 1 else 1
		_expect(
			int((sweep_targets[sweep_stage] as Object).get("clear_count")) == expected,
			"inactive-stage transient sweep should visit stage %d exactly %d time(s)" % [int(sweep_stage), expected]
		)
	# stage8은 아직 미배선 — 스위프가 요청해서는 안 된다. stage8을 정식
	# 배선하는 슬라이스는 이 씰을 {2..8} 계약으로 함께 갱신할 것(스위프
	# 배열과 씰이 따로 놀지 않도록 강제하는 계약).
	for requested_key in sweep_registry.requested_keys:
		_expect(not str(requested_key).begins_with("stage8"), "production sweep must not request stage8 modules yet (got '%s'; update this seal when stage8 lands)" % requested_key)

	# 실 Stage 7 액터 렌더러의 transient 정리 위임: 하위 렌더러 4곳(플레이필드/
	# 플레이어/보스/코만도 화기)으로 clear를 전파해야 한다.
	var real_stage7_renderer: RefCounted = Stage7AkamuActorRenderer.new()
	var stage7_children: Array = []
	for child_property in ["playfield_renderer", "player_renderer", "boss_renderer", "commando_firearm_renderer"]:
		var child := SweepRenderer.new()
		real_stage7_renderer.set(child_property, child)
		stage7_children.append(child)
	real_stage7_renderer.clear_transient_canvas_items()
	for child_index in range(stage7_children.size()):
		_expect(
			int((stage7_children[child_index] as Object).get("clear_count")) == 1,
			"real Stage 7 actor renderer should delegate transient clear to child renderer %d" % child_index
		)

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, {"selected_character_type": "optimus"})
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "explicit non-Smasher characters should skip Smasher wheel state")

	registry.requested_keys.clear()
	drawer.draw_smasher_wheel_effects(null, registry, Vector2.ZERO, {"selected_character_type": "unknown"})
	_expect(not registry.requested_keys.has("smasher_wheel_state"), "unknown nonblank character ids should keep skipping Smasher wheel state")
	_verify_draw_arity_cache(drawer)

	if _failures.is_empty():
		print("battle_playfield_effects_drawer_character_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_draw_arity_cache(drawer: Object) -> void:
	var draw2 := Draw2.new()
	var draw3 := Draw3.new()
	_expect(drawer._get_method_argument_count(draw3, "draw") >= 3, "playfield effects drawer should read draw arity")
	_expect(drawer.get("_method_argument_count_cache").size() == 1, "playfield effects drawer should cache direct arity lookup")
	_expect(drawer._get_method_argument_count(draw3, "draw") >= 3, "playfield effects drawer should reuse draw arity")
	_expect(drawer.get("_method_argument_count_cache").size() == 1, "playfield effects drawer should not grow direct arity cache on repeat")
	_expect(not drawer._method_accepts_argument_count(draw2, "draw", 3), "playfield effects drawer should reject short draw signatures")
	_expect(drawer._method_accepts_argument_count(draw3, "draw", 3), "playfield effects drawer should accept perf-aware draw signatures")
	_expect(drawer.get("_method_acceptance_cache").size() == 2, "playfield effects drawer should cache acceptance by renderer instance")
	_expect(drawer._method_accepts_argument_count(draw3, "draw", 3), "playfield effects drawer should reuse accepted draw signatures")
	_expect(drawer.get("_method_acceptance_cache").size() == 2, "playfield effects drawer should not grow acceptance cache on repeat")


func _has_any_requested(registry: RecordingRegistry, keys: Array[String]) -> bool:
	for key in keys:
		if registry.requested_keys.has(key):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
