extends SceneTree

# expect-zero-object-leaks -- fake registry/runtime references must unwind cleanly.

const LingpetCompanionPlayerRuntimeResolver := preload(
	"res://scripts/lingpet/lingpet_companion_player_runtime_resolver.gd"
)

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var cached_reads: Array[String] = []
	var cold_reads := 0

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_cached_instance(key: String) -> Variant:
		cached_reads.append(key)
		return instances.get(key, null)

	func get_instance(key: String) -> Variant:
		cold_reads += 1
		return instances.get(key, null)


class FakeOverdrive:
	extends RefCounted

	var active := false
	var armed := false

	func is_active() -> bool:
		return active

	func is_armed() -> bool:
		return armed


class FakeViperRuntime:
	extends RefCounted

	var command_armable := false
	var guard_available := true
	var last_owner: Object = null
	var last_registry: Object = null

	func is_command_armable(owner: Object, registry: Object) -> bool:
		last_owner = owner
		last_registry = registry
		return command_armable

	func is_player_guard_available() -> bool:
		return guard_available


class FakeDashState:
	extends RefCounted

	var active := false
	var snapshot: Variant = {}

	func is_active() -> bool:
		return active

	func get_snapshot() -> Variant:
		return snapshot


func _init() -> void:
	_verify_right_click_claims()
	_verify_dash_snapshot_resolution()
	_verify_player_guard_availability()
	if _failures.is_empty():
		print("lingpet_companion_player_runtime_resolver_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_right_click_claims() -> void:
	var resolver := LingpetCompanionPlayerRuntimeResolver.new()
	_expect(not resolver.is_right_click_claimed_by_player_skill(null, null), "missing registry must release right click")
	var owner := RefCounted.new()
	var overdrive := FakeOverdrive.new()
	var viper := FakeViperRuntime.new()
	var registry := FakeRegistry.new({
		"smasher_overdrive_state": overdrive,
		"viper_skill_runtime": viper,
	})
	overdrive.active = true
	_expect(resolver.is_right_click_claimed_by_player_skill(owner, registry), "active Smasher overdrive must claim right click")
	overdrive.active = false
	overdrive.armed = true
	_expect(resolver.is_right_click_claimed_by_player_skill(owner, registry), "armed Smasher overdrive must claim right click")
	overdrive.armed = false
	viper.command_armable = true
	_expect(resolver.is_right_click_claimed_by_player_skill(owner, registry), "armable Viper command must claim right click")
	_expect(viper.last_owner == owner and viper.last_registry == registry, "Viper arbitration must receive the live owner and registry")
	viper.command_armable = false
	_expect(not resolver.is_right_click_claimed_by_player_skill(owner, registry), "denied player skills must release right click to the mount")
	_expect(registry.cold_reads == 0, "right-click arbitration must never cold-instantiate a player runtime")
	# FakeRegistry owns viper through its instance map; clear the observation links
	# so this fixture does not manufacture a RefCounted cycle at SceneTree exit.
	viper.last_owner = null
	viper.last_registry = null


func _verify_dash_snapshot_resolution() -> void:
	var resolver := LingpetCompanionPlayerRuntimeResolver.new()
	var dash := FakeDashState.new()
	var registry := FakeRegistry.new({"smasher_dash_state": dash})
	_expect(resolver.resolve_player_dash_state(registry).is_empty(), "inactive player dash must project an empty snapshot")
	dash.active = true
	dash.snapshot = {"elapsed": 0.25, "duration": 0.8}
	_expect(resolver.resolve_player_dash_state(registry) == dash.snapshot, "active player dash must project its cached snapshot")
	dash.snapshot = "invalid"
	_expect(resolver.resolve_player_dash_state(registry).is_empty(), "non-Dictionary dash snapshots must fail closed")
	_expect(registry.cold_reads == 0, "dash projection must never cold-instantiate Smasher state")


func _verify_player_guard_availability() -> void:
	var resolver := LingpetCompanionPlayerRuntimeResolver.new()
	_expect(resolver.is_player_guard_available(null), "missing Viper runtime must preserve normal player guard")
	var viper := FakeViperRuntime.new()
	var registry := FakeRegistry.new({"viper_skill_runtime": viper})
	viper.guard_available = false
	_expect(not resolver.is_player_guard_available(registry), "Viper guard lock must suppress player-priority blocking")
	viper.guard_available = true
	_expect(resolver.is_player_guard_available(registry), "available Viper guard must preserve player priority")
	_expect(registry.cold_reads == 0, "guard availability must use cached lookup only")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
