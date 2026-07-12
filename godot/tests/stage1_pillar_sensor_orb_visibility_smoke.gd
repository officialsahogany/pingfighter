extends SceneTree

# Seal: 위험감지센서 pillar 대쉬토큰 오브 가시성.
#
# 패시브→퍽 전환(PerkConversionFlags ON) 이후 센서는 equipped_items에 없다.
# pillar HUD의 sensor 오브 게이트가 "equipped"만 보면 퍽 획득 시 오브가 사라진다.
# 이 씰은 (1) 컨텍스트 빌더가 퍽-인지 "active" 플래그를 노출하는지, (2) 렌더러의
# 가시성 판정 _is_sensor_orb_visible()가 퍽 경로에서 true인지를 실제 경로로 봉인한다.
#
# 반증검증(수동): stage1_pillar_ui_renderer._is_sensor_orb_visible를 "equipped"만
# 읽도록 되돌리면 perk-path 레그가 RED / mythic_item_context_builder에서 "active"
# 키를 제거하면 컨텍스트 레그가 RED가 되어야 한다 (in-place 토글, git reset 금지).

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")

const SENSOR_ID := "sensor"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeRegistry:
	extends RefCounted

	var _runtime_perk_state: Object

	func _init(state_ref: Object) -> void:
		_runtime_perk_state = state_ref

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return _runtime_perk_state
		return null


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_context_exposes_active_flag_for_perk()
	_verify_context_active_false_when_perk_unowned()
	_verify_context_active_true_for_equipped_item_flag_off()
	_verify_context_active_false_when_absent_flag_off()
	_verify_renderer_predicate_gates()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("stage1_pillar_sensor_orb_visibility_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


# flag ON + 센서 퍽 레벨>0 → active=true 이면서 equipped=false.
# 이것이 회귀의 핵심 레그: 퍽만 있고 아이템 장착이 없어도 오브가 보여야 한다.
func _verify_context_exposes_active_flag_for_perk() -> void:
	var env: Dictionary = _make_perk_env({SENSOR_ID: 1})
	var runtime: Object = env["runtime"]
	var context: Dictionary = runtime.get_sensor_context()
	_expect(context.has("active"), "sensor context should expose an 'active' visibility flag")
	_expect(bool(context.get("active", false)), "ON perk sensor should be visibility-active")
	_expect(not bool(context.get("equipped", true)), "ON perk sensor should NOT be equipped as an item")
	_expect(runtime.is_sensor_effect_active(), "ON perk sensor effect gate should be active")


# flag ON + 센서 퍽 미보유(레벨 0) → active=false.
func _verify_context_active_false_when_perk_unowned() -> void:
	var env: Dictionary = _make_perk_env({})
	var runtime: Object = env["runtime"]
	var context: Dictionary = runtime.get_sensor_context()
	_expect(not bool(context.get("active", true)), "ON but unowned sensor should be visibility-inactive")


# flag OFF + 센서 아이템 장착 → active=true, equipped=true (레거시 파리티).
func _verify_context_active_true_for_equipped_item_flag_off() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var owner := FakeOwner.new()
	_expect(
		runtime.equip_item(SENSOR_ID, owner, null, {"sensor_cooldown_sec": 13.0}, false),
		"OFF sensor fixture should equip"
	)
	var context: Dictionary = runtime.get_sensor_context()
	_expect(bool(context.get("active", false)), "OFF equipped sensor should be visibility-active")
	_expect(bool(context.get("equipped", false)), "OFF equipped sensor should report equipped")


# flag OFF + 미장착 → active=false.
func _verify_context_active_false_when_absent_flag_off() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var context: Dictionary = runtime.get_sensor_context()
	_expect(not bool(context.get("active", true)), "OFF unequipped sensor should be visibility-inactive")


# 렌더러 판정 헬퍼 직접 봉인 (draw 게이트의 단일 소스).
func _verify_renderer_predicate_gates() -> void:
	var renderer := Stage1PillarUiRenderer.new()
	_expect(not renderer._is_sensor_orb_visible({}), "empty sensor context should hide the orb")
	# 회귀 핵심: 퍽 경로(equipped=false, active=true)에서 오브가 보여야 한다.
	_expect(
		renderer._is_sensor_orb_visible({"equipped": false, "active": true}),
		"perk-path sensor (active, not equipped) should show the orb"
	)
	_expect(
		renderer._is_sensor_orb_visible({"equipped": true, "active": true}),
		"equipped+active sensor should show the orb"
	)
	_expect(
		not renderer._is_sensor_orb_visible({"equipped": false, "active": false}),
		"inactive+unequipped sensor should hide the orb"
	)
	# active가 명시적으로 false면 equipped=true여도 숨긴다 (active가 우선).
	_expect(
		not renderer._is_sensor_orb_visible({"equipped": true, "active": false}),
		"explicit active=false should win over equipped=true"
	)
	# 레거시 스냅샷 호환: active 키가 없으면 equipped로 폴백.
	_expect(
		renderer._is_sensor_orb_visible({"equipped": true}),
		"legacy context without 'active' should fall back to equipped"
	)
	_expect(
		not renderer._is_sensor_orb_visible({"equipped": false}),
		"legacy context without 'active' and unequipped should hide"
	)


func _make_perk_env(levels: Dictionary) -> Dictionary:
	PerkConversionFlags.debug_set_enabled(true)
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var state := RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	var registry := FakeRegistry.new(state)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return {
		"runtime": runtime,
		"state": state,
		"registry": registry,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
